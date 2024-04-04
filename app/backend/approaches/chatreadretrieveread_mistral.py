# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

import json
import re
import logging
import urllib.parse
from datetime import datetime, timedelta
from typing import Any, Sequence

import openai
from approaches.approach import Approach
from azure.core.credentials import AzureKeyCredential 
from azure.search.documents import SearchClient  
from azure.search.documents.indexes import SearchIndexClient  
from azure.search.documents.models import RawVectorQuery
from azure.search.documents.models import QueryType

from text import nonewlines
from datetime import datetime, timedelta
from azure.storage.blob import (
    AccountSasPermissions,
    BlobServiceClient,
    ResourceTypes,
    generate_account_sas,
)
from text import nonewlines
import tiktoken
from core.messagebuilder import MessageBuilder
from core.modelhelper import get_token_limit
from core.modelhelper import num_tokens_from_messages
import requests
from urllib.parse import quote

# Simple retrieve-then-read implementation, using the Cognitive Search and
# OpenAI APIs directly. It first retrieves top documents from search,
# then constructs a prompt with them, and then uses OpenAI to generate
# an completion (answer) with that prompt.

class ChatReadRetrieveReadApproachMistral(Approach):

     # Chat roles
    SYSTEM = "system"
    USER = "user"
    ASSISTANT = "assistant"


    # # Define a class variable for the base URL
    # EMBEDDING_SERVICE_BASE_URL = 'https://infoasst-cr-{}.azurewebsites.net'
    
    def __init__(
        self,
        search_client: str,
        source_file_field: str,
        content_field: str,
        page_number_field: str,
        chunk_file_field: str,
        content_storage_container: str,
        blob_client: BlobServiceClient,
        query_term_language: str,
        model_name: str,
        model_version: str,
        is_gov_cloud_deployment: str,
        IS_CONTAINERIZED_DEPLOYMENT: str,
        TARGET_EMBEDDING_MODEL: str,
    ):
        self.search_client = search_client
        self.source_file_field = source_file_field
        self.content_field = content_field
        self.page_number_field = page_number_field
        self.chunk_file_field = chunk_file_field
        self.content_storage_container = content_storage_container
        self.blob_client = blob_client
        self.query_term_language = query_term_language
        self.chatgpt_token_limit = get_token_limit(model_name)
        #escape target embeddiong model name
        self.escaped_target_model = re.sub(r'[^a-zA-Z0-9_\-.]', '_', TARGET_EMBEDDING_MODEL)
        
        self.embedding_service_url = f'http://infoasst-enrichment.infoasst.svc.cluster.local'
        
        self.llm_api_base = 'http://infoasst-llm.infoasst.svc.cluster.local:8080/'

        self.model_name = model_name
        self.model_version = model_version
        self.is_gov_cloud_deployment = is_gov_cloud_deployment
        self.IS_CONTAINERIZED_DEPLOYMENT = IS_CONTAINERIZED_DEPLOYMENT

    def remove_html_tags(self, text):
        pattern = re.compile('<.*?>')
        clean_text = re.sub(pattern, '', text)
        return clean_text    

    # def run(self, history: list[dict], overrides: dict) -> any:
    def run(self, history: Sequence[dict[str, str]], overrides: dict[str, Any]) -> Any:
        top = overrides.get("top") or 3
        user_persona = overrides.get("user_persona", "")
        system_persona = overrides.get("system_persona", "")
        response_length = int(overrides.get("response_length") or 1024)
        folder_filter = overrides.get("selected_folders", "")
        tags_filter = overrides.get("selected_tags", "")

        # STEP 1: Generate an optimized keyword search query based on the chat history and the last question

        generated_query = history[-1]["user"]

        r = self.search_client.query(top=top, query=generated_query)

        citation_lookup = {}  # dict of "FileX" moniker to the actual file name
        results = []  # list of results to be used in the prompt
        data_points = []  # list of data points to be used in the respons
        
        cutoff_score = .4
        counter = 0
        for result in r:
            text = self.remove_html_tags(result['text'])
            title = result['title']
            source = result['source']
            score = result['_additional']['score']
            rerank_score = result['_additional']['rerank'][0]['score']
            if float(score) > cutoff_score:
                results.append(
                    f"[File{counter}]"+nonewlines(text)+"]\n" # figure out where to get id
                    ) 

                data_points.append(
                "/".join(urllib.parse.unquote(title).split("/")[4:]
                    ) + "| " + nonewlines(text)
                    )

                citation_lookup[f"File{counter}"] = {
                    "citation": urllib.parse.unquote("https://" + source.split("/")[2] + f"/{self.content_storage_container}/" + source.split("/")[4] + "/" + source.split("/")[4].split(".")[0] + "-" + str(counter) + ".json"),
                    "source_path": self.get_source_file_with_sas(source),
                    "page_number": "0",
                }         
                counter = counter + 1       

        # create a single string of all the results to be used in the prompt
        results_text = "".join(results)
        if results_text == "":
            content = "\n NONE"
        else:
            content = "\n " + results_text

        # STEP 3: Generate the prompt to be sent to the GPT model
        follow_up_questions_prompt = (
            self.follow_up_questions_prompt_content
            if overrides.get("suggest_followup_questions")
            else ""
        )

        # Allow client to replace the entire prompt, or to inject into the existing prompt using >>>
        prompt_override = overrides.get("prompt_template")

        last_question = history[-1]["user"]

        messages = """
        I will present a question followed by a context block. The context is divided into sections delimited by | symbols, each labeled with a unique filename in the format [FileX], where X is a unique identifier. Your task is to find the section(s) most relevant to the question, use only that section(s) to form your answer, and cite the section(s) accordingly. Let's go through a simplified example to illustrate how to do this.

        Example Question: What languages are spoken in Monaco?        
        Example Context: | [File1] "The LaFerrari has 950 horsepower." |
        | [File7] The official language of Monaco is French. Monégasque, a variety of Ligurian, is the national language of the Monégasque people. However, it is the primary language of very few people. There are several other languages spoken in addition to French and Monégasque, including Italian and English |
        | [File5] The population of Switzerland as of 2022 is approximately 8.77 million people. |

        1. Read the Question: Understand that the question is asking for the languages spoken in Monaco.

        2. Identify Relevant Section(s): Scan for keywords related to 'languages' and 'Monaco'. [File7] is directly relevant as it mentions the languages spoken in Monaco.

        3. Extract Pertinent Information: From [File7], we find that "The official language of Monaco is French. Monégasque, a variety of Ligurian, is the national language of the Monégasque people. However, it is the primary language of very few people. There are several other languages spoken in addition to French and Monégasque, including Italian and English"

        4. Synthesize Your Answer: Since only [File7] is relevant and it provides a direct answer, there's no need for synthesis with other sections.

        5. Cite the Section(s) Used: Cite [File7] as the source of our answer.

        6. Formulate Your Answer: [File7] The languages spoken in Monaco are English, French, Italian and Monégasque.

        Now, let's apply this method to a real question with its context block. Remember, it's crucial to use only the information from the context provided and to cite the specific section(s) used in your answer. If you cannot answer the question using the provided context, it is critical that you ONLY respond with I am not sure

        Question: {question}
        Context: {content}
        Answer:
        """.format(question = last_question, content = content)
        url = f'{self.llm_api_base}/predict'
        headers = {'Content-Type': 'application/json',}
        data = {'text': messages,}
        chat_completion = requests.post(url, headers=headers, data=json.dumps(data))
        chat_completion = json.loads(chat_completion.text)
        generated_query = chat_completion[0]['generated_text'].split("Answer:")[-1]
        #if we fail to generate a query, return the last user question
        if generated_query.strip() == "0":
            generated_query = history[-1]["user"]

        # STEP 4: Format the response

        chain_of_thought = chat_completion[0]['generated_text'].split("Question: "+last_question)[1]

        return {
            "data_points": data_points,
            "answer": f"{urllib.parse.unquote(generated_query)}",
            "thoughts": f"Searched for:<br>{last_question}<br><br>Conversations:<br>" + chain_of_thought.replace('\n', '<br>'),
            "citation_lookup": citation_lookup
        }

    #Aparmar. Custom method to construct Chat History as opposed to single string of chat History.
    def get_messages_from_history(
        self,
        system_prompt: str,
        model_id: str,
        history: Sequence[dict[str, str]],
        user_conv: str,
        few_shots = [],
        max_tokens: int = 4096) -> []:
        """
        Construct a list of messages from the chat history and the user's question.
        """
        message_builder = MessageBuilder(system_prompt, model_id)

        # Few Shot prompting. Add examples to show the chat what responses we want. It will try to mimic any responses and make sure they match the rules laid out in the system message.
        for shot in few_shots:
            message_builder.append_message(shot.get('role'), shot.get('content'))

        user_content = user_conv
        append_index = len(few_shots) + 1

        message_builder.append_message(self.USER, user_content, index=append_index)

        for h in reversed(history[:-1]):
            if h.get("bot"):
                message_builder.append_message(self.ASSISTANT, h.get('bot'), index=append_index)
            message_builder.append_message(self.USER, h.get('user'), index=append_index)
            if message_builder.token_length > max_tokens:
                break

        messages = message_builder.messages

        return messages

    #Get the prompt text for the response length
    def get_response_length_prompt_text(self, response_length: int):
        """ Function to return the response length prompt text"""
        levels = {
            1024: "succinct",
            2048: "standard",
            3072: "thorough",
        }
        level = levels[response_length]
        return f"Please provide a {level} answer. This means that your answer should be no more than {response_length} tokens long."

    def num_tokens_from_string(self, string: str, encoding_name: str) -> int:
        """ Function to return the number of tokens in a text string"""
        encoding = tiktoken.get_encoding(encoding_name)
        num_tokens = len(encoding.encode(string))
        return num_tokens

    def get_source_file_with_sas(self, source_file: str) -> str:
        """ Function to return the source file with a SAS token"""
        try:
            sas_token = generate_account_sas(
                self.blob_client.account_name,
                self.blob_client.credential.account_key,
                resource_types=ResourceTypes(object=True, service=True, container=True),
                permission=AccountSasPermissions(
                    read=True,
                    write=True,
                    list=True,
                    delete=False,
                    add=True,
                    create=True,
                    update=True,
                    process=False,
                ),
                expiry=datetime.utcnow() + timedelta(hours=1),
            )
            return source_file + "?" + sas_token
        except Exception as error:
            logging.error(f"Unable to parse source file name: {str(error)}")
            return ""
