# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

from io import StringIO
from typing import Optional
import asyncio
#from sse_starlette.sse import EventSourceResponse
#from starlette.responses import StreamingResponse
from starlette.responses import Response
import logging
import os
import json
import urllib.parse
import pandas as pd
from datetime import datetime, timedelta
from fastapi.staticfiles import StaticFiles
from fastapi import FastAPI, File, HTTPException, Request, UploadFile
from fastapi.responses import RedirectResponse, StreamingResponse
import openai
from approaches.comparewebwithwork import CompareWebWithWork
from approaches.compareworkwithweb import CompareWorkWithWeb
from approaches.chatwebretrieveread import ChatWebRetrieveRead
from approaches.gpt_direct_approach import GPTDirectApproach
from approaches.approach import Approaches
from approaches.chatreadretrieveread import ChatReadRetrieveReadApproach
from approaches.chatreadretrieveread_mistral import ChatReadRetrieveReadApproachMistral
from azure.core.credentials import AzureKeyCredential
from azure.identity import DefaultAzureCredential, AzureAuthorityHosts
from azure.keyvault.secrets import SecretClient
from azure.mgmt.cognitiveservices import CognitiveServicesManagementClient
from azure.search.documents import SearchClient
from azure.storage.blob import (
    AccountSasPermissions,
    BlobServiceClient,
    ResourceTypes,
    generate_account_sas,
)
from approaches.mathassistant import(
    generate_response,
    process_agent_scratch_pad,
    process_agent_response,
    stream_agent_responses
)
from approaches.tabulardataassistant import (
    refreshagent,
    save_df,
    process_agent_response as td_agent_response,
    process_agent_scratch_pad as td_agent_scratch_pad,
    get_images_in_temp

)
from shared_code.status_log import State, StatusClassification, StatusLog
from azure.cosmos import CosmosClient
from langchain.retrievers.weaviate_hybrid_search import WeaviateHybridSearchRetriever
import weaviate
from fastapi import FastAPI, Depends
from auth import router as auth_router, get_current_user
from fastapi.responses import HTMLResponse, FileResponse, RedirectResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
# === ENV Setup ===

str_to_bool = {'true': True, 'false': False}
# Replace these with your own values, either in environment variables or directly here
AZURE_BLOB_STORAGE_ACCOUNT = (os.environ.get("AZURE_BLOB_STORAGE_ACCOUNT") or "mystorageaccount")
AZURE_BLOB_STORAGE_ENDPOINT = os.environ.get("AZURE_BLOB_STORAGE_ENDPOINT") 
AZURE_BLOB_STORAGE_CONTAINER = (os.environ.get("AZURE_BLOB_STORAGE_CONTAINER") or "content")
AZURE_BLOB_STORAGE_UPLOAD_CONTAINER = (os.environ.get("AZURE_BLOB_STORAGE_UPLOAD_CONTAINER") or "upload")
AZURE_KEYVAULT_NAME = os.environ.get("AZURE_KEYVAULT_NAME") or ""
AZURE_SEARCH_SERVICE = os.environ.get("AZURE_SEARCH_SERVICE") or "gptkb"
AZURE_SEARCH_SERVICE_ENDPOINT = os.environ.get("AZURE_SEARCH_SERVICE_ENDPOINT")
AZURE_SEARCH_INDEX = os.environ.get("AZURE_SEARCH_INDEX") or "gptkbindex"
USE_SEMANTIC_RERANKER = os.environ.get("USE_SEMANTIC_RERANKER" or True)

AZURE_OPENAI_SERVICE = os.environ.get("AZURE_OPENAI_SERVICE") or "myopenai"
AZURE_OPENAI_RESOURCE_GROUP = os.environ.get("AZURE_OPENAI_RESOURCE_GROUP") or ""
AZURE_OPENAI_ENDPOINT = os.environ.get("AZURE_OPENAI_ENDPOINT") or ""
AZURE_OPENAI_AUTHORITY_HOST = os.environ.get("AZURE_OPENAI_AUTHORITY_HOST") or "AzureCloud"
AZURE_OPENAI_CHATGPT_DEPLOYMENT = (os.environ.get("AZURE_OPENAI_CHATGPT_DEPLOYMENT") or "gpt-4")
AZURE_OPENAI_CHATGPT_MODEL_NAME = ( os.environ.get("AZURE_OPENAI_CHATGPT_MODEL_NAME") or "")
AZURE_OPENAI_CHATGPT_MODEL_VERSION = ( os.environ.get("AZURE_OPENAI_CHATGPT_MODEL_VERSION") or "")
USE_AZURE_OPENAI_EMBEDDINGS = str_to_bool.get(os.environ.get("USE_AZURE_OPENAI_EMBEDDINGS", "").lower()) or False
EMBEDDING_DEPLOYMENT_NAME = ( os.environ.get("EMBEDDING_DEPLOYMENT_NAME") or "")
AZURE_OPENAI_EMBEDDINGS_MODEL_NAME = ( os.environ.get("AZURE_OPENAI_EMBEDDINGS_MODEL_NAME") or "")
AZURE_OPENAI_EMBEDDINGS_VERSION = ( os.environ.get("AZURE_OPENAI_EMBEDDINGS_VERSION") or "")
AZURE_SUBSCRIPTION_ID = os.environ.get("AZURE_SUBSCRIPTION_ID")
AZURE_ARM_MANAGEMENT_API = os.environ.get("AZURE_ARM_MANAGEMENT_API") or "https://management.azure.us"
CHAT_WARNING_BANNER_TEXT = os.environ.get("CHAT_WARNING_BANNER_TEXT") or ""
APPLICATION_TITLE = os.environ.get("APPLICATION_TITLE") or "Information Assistant, built with Azure OpenAI"

KB_FIELDS_CONTENT = os.environ.get("KB_FIELDS_CONTENT") or "content"
KB_FIELDS_PAGENUMBER = os.environ.get("KB_FIELDS_PAGENUMBER") or "pages"
KB_FIELDS_SOURCEFILE = os.environ.get("KB_FIELDS_SOURCEFILE") or "file_uri"
KB_FIELDS_CHUNKFILE = os.environ.get("KB_FIELDS_CHUNKFILE") or "chunk_file"

COSMOSDB_URL = os.environ.get("COSMOSDB_URL") or  None
COSMOSDB_LOG_DATABASE_NAME = os.environ.get("COSMOSDB_LOG_DATABASE_NAME") or "statusdb"
COSMOSDB_LOG_CONTAINER_NAME = os.environ.get("COSMOSDB_LOG_CONTAINER_NAME") or "statuscontainer"

QUERY_TERM_LANGUAGE = os.environ.get("QUERY_TERM_LANGUAGE") or "English"

TARGET_EMBEDDINGS_MODEL = os.environ.get("TARGET_EMBEDDINGS_MODEL") or "BAAI/bge-small-en-v1.5"
ENRICHMENT_APPSERVICE_URL = os.environ.get("ENRICHMENT_APPSERVICE_URL") or "http://infoasst-enrichment.infoasst.svc.cluster.local"
ENRICHMENT_ENDPOINT = os.environ.get("ENRICHMENT_ENDPOINT") or None

AZURE_AI_TRANSLATION_DOMAIN = os.environ.get("AZURE_AI_TRANSLATION_DOMAIN") or "api.cognitive.microsofttranslator.com"
TARGET_TRANSLATION_LANGUAGE = os.environ.get("TARGET_TRANSLATION_LANGUAGE") or "en"
BING_SEARCH_ENDPOINT = os.environ.get("BING_SEARCH_ENDPOINT") or "https://api.bing.microsoft.com"
BING_SEARCH_KEY = os.environ.get("BING_SEARCH_KEY") or ""
ENABLE_BING_SAFE_SEARCH = str_to_bool.get(os.environ.get("ENABLE_BING_SAFE_SEARCH").lower()) or True
ENABLE_WEB_CHAT = str_to_bool.get(os.environ.get("ENABLE_WEB_CHAT").lower()) or False
ENABLE_UNGROUNDED_CHAT = str_to_bool.get(os.environ.get("ENABLE_UNGROUNDED_CHAT").lower()) or False
ENABLE_MATH_ASSISTANT = str_to_bool.get(os.environ.get("ENABLE_MATH_ASSISTANT").lower()) or False
ENABLE_TABULAR_DATA_ASSISTANT = str_to_bool.get(os.environ.get("ENABLE_TABULAR_DATA_ASSISTANT").lower()) or False
ENABLE_MULTIMEDIA = str_to_bool.get(os.environ.get("ENABLE_MULTIMEDIA").lower()) or False
MAX_CSV_FILE_SIZE = os.environ.get("MAX_CSV_FILE_SIZE") or "7"

#################### CF ENV vars for containerized deployment ####################
WEAVIATE_URL = os.environ.get("WEAVIATE_URL", "") 
WEAVIATE_INDEX_NAME = os.environ.get("WEAVIATE_INDEX", "WEAVIATE")
DISCONNECTED_AI = str_to_bool.get(os.environ.get("DISCONNECTED_AI"))
AZURE_LOCATION = os.environ.get("AZURE_LOCATION")
##################################################################################

log = logging.getLogger("uvicorn")
log.setLevel('DEBUG')
log.propagate = True

dffinal = None
# Use the current user identity to authenticate with Azure OpenAI, Cognitive Search and Blob Storage (no secrets needed,
# just use 'az login' locally, and managed identity when deployed on Azure). If you need to use keys, use separate AzureKeyCredential instances with the
# keys for each service
# If you encounter a blocking error during a DefaultAzureCredntial resolution, you can exclude the problematic credential by using a parameter (ex. exclude_shared_token_cache_credential=True)
kv_uri = AZURE_KEYVAULT_NAME

if AZURE_OPENAI_AUTHORITY_HOST == "AzureUSGovernment":
    AUTHORITY = AzureAuthorityHosts.AZURE_GOVERNMENT
else:
    AUTHORITY = AzureAuthorityHosts.AZURE_PUBLIC_CLOUD

azure_credential = DefaultAzureCredential(authority=AUTHORITY)

keyVaultClient = SecretClient(vault_url=kv_uri, credential=azure_credential)

if DISCONNECTED_AI:
    AZURE_OPENAI_SERVICE_KEY = AZURE_SEARCH_SERVICE_KEY = ""
else:
    AZURE_OPENAI_SERVICE_KEY = keyVaultClient.get_secret("AZURE-OPENAI-SERVICE-KEY").value
    AZURE_SEARCH_SERVICE_KEY = keyVaultClient.get_secret("AZURE-SEARCH-SERVICE-KEY").value

AZURE_BLOB_STORAGE_KEY = keyVaultClient.get_secret("AZURE-BLOB-STORAGE-KEY").value
COSMOSDB_KEY = keyVaultClient.get_secret("COSMOSDB-KEY").value
ENRICHMENT_KEY = keyVaultClient.get_secret("ENRICHMENT-KEY").value

azure_search_key_credential = AzureKeyCredential(AZURE_SEARCH_SERVICE_KEY)

# Used by the OpenAI SDK
openai.api_type = "azure"
openai.api_version = "2023-12-01-preview"
openai.api_base = AZURE_OPENAI_ENDPOINT

# Comment these two lines out if using keys, set your API key in the OPENAI_API_KEY environment variable instead
# openai.api_type = "azure_ad"
# openai_token = azure_credential.get_token("https://cognitiveservices.azure.com/.default")
openai.api_key = AZURE_OPENAI_SERVICE_KEY

# Setup StatusLog to allow access to CosmosDB for logging
statusLog = StatusLog(
    COSMOSDB_URL, COSMOSDB_KEY, COSMOSDB_LOG_DATABASE_NAME, COSMOSDB_LOG_CONTAINER_NAME
)

azure_search_key_credential = AzureKeyCredential(AZURE_SEARCH_SERVICE_KEY)

# Set up clients for Cognitive Search and Storage
class WeaviateSearch:
    """A wrapper for a Weaviate search client."""
    def __init__(self, url, index_name):
        self.url = url
        self.index_name = WEAVIATE_INDEX_NAME  
        self.weaviate_client = weaviate.Client(url)

        # if index isn't created, create it
        if not self.weaviate_client.schema.exists(index_name):
            class_obj = {
                    "class": index_name,
                    "vectorizer": "text2vec-transformers",
                    "moduleConfig": {
                        "reranker-transformers": {
                            "model": "cross-encoder-ms-marco-MiniLM-L-6-v2",
                        }
                    },
            }
            self.weaviate_client.schema.create_class(class_obj)
     
        self.search_client = WeaviateHybridSearchRetriever(
                    client=self.weaviate_client,
                    index_name=index_name,
                    text_key="text",
                    # k=10,
                    # alpha=0.50,
                    attributes=[],
                    create_schema_if_missing=True,
                )
        
    def query(self, top, query):

        limit = top if top > 10 else 10  # Limit the number of results to 10
 
        # hybrid search
        response = (
            self.weaviate_client.query
            .get(self.index_name, ["text", "source", "title",  "language", "chunk_file"])
            .with_hybrid(
                query=query,
            )
            .with_additional("score") # "explainScore"
            .with_additional('rerank(property: "text") { score }')
            .with_limit(limit) # take the top results prior to reranking
            .do()
        ).get('data', {}).get('Get', {}).get(WEAVIATE_INDEX_NAME, [])[:top] 

        return response

if DISCONNECTED_AI:
    search_client = WeaviateSearch(
        url=WEAVIATE_URL, 
        index_name=WEAVIATE_INDEX_NAME
    )
else:
    search_client = SearchClient(
        endpoint=AZURE_SEARCH_SERVICE_ENDPOINT,
        index_name=AZURE_SEARCH_INDEX,
        credential=azure_search_key_credential,
    )

default_credential = DefaultAzureCredential()
blob_client = BlobServiceClient(AZURE_BLOB_STORAGE_ENDPOINT, credential=default_credential)

blob_container = blob_client.get_container_client(AZURE_BLOB_STORAGE_CONTAINER)

model_name = ''
model_version = ''

# Set up OpenAI management client
if DISCONNECTED_AI:
    model_name = "mistral"
else:
    openai_mgmt_client = CognitiveServicesManagementClient(
        credential=azure_credential,
        subscription_id=AZURE_SUBSCRIPTION_ID,
        base_url=AZURE_ARM_MANAGEMENT_API,
        credential_scopes=[AZURE_ARM_MANAGEMENT_API + "/.default"])

## This is needed for OpenAI instances that do not exist in the same RG
    if (AZURE_OPENAI_RESOURCE_GROUP == ""):
        model_name = AZURE_OPENAI_CHATGPT_MODEL_NAME
        model_version = AZURE_OPENAI_CHATGPT_MODEL_VERSION
        embedding_model_name = AZURE_OPENAI_EMBEDDINGS_MODEL_NAME
        embedding_model_version = AZURE_OPENAI_EMBEDDINGS_VERSION
    else:
        deployment = openai_mgmt_client.deployments.get(
            resource_group_name=AZURE_OPENAI_RESOURCE_GROUP,
            account_name=AZURE_OPENAI_SERVICE,
            deployment_name=AZURE_OPENAI_CHATGPT_DEPLOYMENT)

        model_name = deployment.properties.model.name
        model_version = deployment.properties.model.version

        if USE_AZURE_OPENAI_EMBEDDINGS:
            embedding_deployment = openai_mgmt_client.deployments.get(
                resource_group_name=AZURE_OPENAI_RESOURCE_GROUP,
                account_name=AZURE_OPENAI_SERVICE,
                deployment_name=EMBEDDING_DEPLOYMENT_NAME)

            embedding_model_name = embedding_deployment.properties.model.name
            embedding_model_version = embedding_deployment.properties.model.version
        else:
            embedding_model_name = ""
            embedding_model_version = ""


if DISCONNECTED_AI:
    chat_approaches = {
        "rrr": ChatReadRetrieveReadApproachMistral(
            search_client,
            KB_FIELDS_SOURCEFILE,
            KB_FIELDS_CONTENT,
            KB_FIELDS_PAGENUMBER,
            KB_FIELDS_CHUNKFILE,
            AZURE_BLOB_STORAGE_CONTAINER,
            blob_client,
            QUERY_TERM_LANGUAGE,
            model_name,
            DISCONNECTED_AI,
            TARGET_EMBEDDINGS_MODEL,
        )
    }
else:  
    chat_approaches = {
        Approaches.ReadRetrieveRead: ChatReadRetrieveReadApproach(
                                        search_client,
                                        AZURE_OPENAI_ENDPOINT,
                                        AZURE_OPENAI_SERVICE_KEY,
                                        AZURE_OPENAI_CHATGPT_DEPLOYMENT,
                                        KB_FIELDS_SOURCEFILE,
                                        KB_FIELDS_CONTENT,
                                        KB_FIELDS_PAGENUMBER,
                                        KB_FIELDS_CHUNKFILE,
                                        AZURE_BLOB_STORAGE_CONTAINER,
                                        blob_client,
                                        QUERY_TERM_LANGUAGE,
                                        model_name,
                                        model_version,
                                        TARGET_EMBEDDINGS_MODEL,
                                        ENRICHMENT_APPSERVICE_URL,
                                        TARGET_TRANSLATION_LANGUAGE,
                                        ENRICHMENT_ENDPOINT,
                                        AZURE_LOCATION,
                                        ENRICHMENT_KEY,
                                        AZURE_AI_TRANSLATION_DOMAIN,
                                        USE_SEMANTIC_RERANKER,
                                        DISCONNECTED_AI
        ),
        Approaches.ChatWebRetrieveRead: ChatWebRetrieveRead(
                                        model_name,
                                        AZURE_OPENAI_CHATGPT_DEPLOYMENT,
                                        TARGET_TRANSLATION_LANGUAGE,
                                        BING_SEARCH_ENDPOINT,
                                        BING_SEARCH_KEY,
                                        ENABLE_BING_SAFE_SEARCH
        ),
        Approaches.CompareWorkWithWeb: CompareWorkWithWeb( 
                                        model_name,
                                        AZURE_OPENAI_CHATGPT_DEPLOYMENT,
                                        TARGET_TRANSLATION_LANGUAGE,
                                        BING_SEARCH_ENDPOINT,
                                        BING_SEARCH_KEY,
                                        ENABLE_BING_SAFE_SEARCH
        ),
        Approaches.CompareWebWithWork: CompareWebWithWork(
                                        search_client,
                                        AZURE_OPENAI_ENDPOINT,
                                        AZURE_OPENAI_SERVICE_KEY,
                                        AZURE_OPENAI_CHATGPT_DEPLOYMENT,
                                        KB_FIELDS_SOURCEFILE,
                                        KB_FIELDS_CONTENT,
                                        KB_FIELDS_PAGENUMBER,
                                        KB_FIELDS_CHUNKFILE,
                                        AZURE_BLOB_STORAGE_CONTAINER,
                                        blob_client,
                                        QUERY_TERM_LANGUAGE,
                                        model_name,
                                        model_version,
                                        TARGET_EMBEDDINGS_MODEL,
                                        ENRICHMENT_APPSERVICE_URL,
                                        TARGET_TRANSLATION_LANGUAGE,
                                        ENRICHMENT_ENDPOINT,
                                        ENRICHMENT_KEY,
                                        AZURE_AI_TRANSLATION_DOMAIN,
                                        USE_SEMANTIC_RERANKER
                                    ),
        Approaches.GPTDirect: GPTDirectApproach(
                                    AZURE_OPENAI_SERVICE,
                                    AZURE_OPENAI_SERVICE_KEY,
                                    AZURE_OPENAI_CHATGPT_DEPLOYMENT,
                                    QUERY_TERM_LANGUAGE,
                                    model_name,
                                    model_version,
                                    AZURE_OPENAI_ENDPOINT
        )
    }

app = FastAPI(
    title="IA Web API",
    description="A Python API to serve as Backend For the Information Assistant Web App",
    version="0.1.0",
    docs_url="/docs",
    dependencies=[Depends(get_current_user)], # The dependency that protects all of the endpoints
)

app.include_router(auth_router, prefix="/auth")

app.mount("/static", StaticFiles(directory="static"), name="static")

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    if exc.status_code == 401:
        return RedirectResponse(url="/auth/login")
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})

@app.get("/", include_in_schema=False, response_class=RedirectResponse)
async def root():
    """Redirect to the index.html page"""
    return RedirectResponse(url="/home")

@app.get("/index.html")
async def redirect_to_home():
    return RedirectResponse(url="/home")

@app.get("/home", response_class=HTMLResponse)
async def home(request: Request):
    return FileResponse("static/index.html")

@app.post("/chat")
async def chat(request: Request):
    """Chat with the bot using a given approach

    Args:
        request (Request): The incoming request object

    Returns:
        dict: The response containing the chat results

    Raises:
        dict: The error response if an exception occurs during the chat
    """
    json_body = await request.json()
    
    try:
        # If block for internal LLM
        if DISCONNECTED_AI:
            approach = "rrr"
            impl = chat_approaches.get(approach)
            r = impl.run(json_body["history"], json_body.get("overrides") or {})
        else:
            approach = json_body.get("approach")
            impl = chat_approaches.get(Approaches(int(approach)))
            if not impl:
                return {"error": "unknown approach"}, 400
            
            if (Approaches(int(approach)) == Approaches.CompareWorkWithWeb or Approaches(int(approach)) == Approaches.CompareWebWithWork):
                r = await impl.run(json_body.get("history", []), json_body.get("overrides", {}), json_body.get("citation_lookup", {}), json_body.get("thought_chain", {}))
            else:
                r = await impl.run(json_body.get("history", []), json_body.get("overrides", {}), {}, json_body.get("thought_chain", {}))
       
        response = {
                "data_points": r["data_points"],
                "answer": r["answer"],
                "thoughts": r["thoughts"],
                "thought_chain": r["thought_chain"],
                "work_citation_lookup": r["work_citation_lookup"],
                "web_citation_lookup": r["web_citation_lookup"]
        }

        return response

    except Exception as ex:
        log.error(f"Error in chat:: {ex}")
        raise HTTPException(status_code=500, detail=str(ex)) from ex


    

@app.get("/getblobclienturl")
async def get_blob_client_url():
    """Get a URL for a file in Blob Storage with SAS token.

    This function generates a Shared Access Signature (SAS) token for accessing a file in Blob Storage.
    The generated URL includes the SAS token as a query parameter.

    Returns:
        dict: A dictionary containing the URL with the SAS token.
    """
    sas_token = generate_account_sas(
        AZURE_BLOB_STORAGE_ACCOUNT,
        AZURE_BLOB_STORAGE_KEY,
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
    return {"url": f"{blob_client.url}?{sas_token}"}

@app.post("/getalluploadstatus")
async def get_all_upload_status(request: Request):
    """
    Get the status and tags of all file uploads in the last N hours.

    Parameters:
    - request: The HTTP request object.

    Returns:
    - results: The status of all file uploads in the specified timeframe.
    """
    json_body = await request.json()
    timeframe = json_body.get("timeframe")
    state = json_body.get("state")
    folder = json_body.get("folder")
    tag = json_body.get("tag")   
    try:
        results = statusLog.read_files_status_by_timeframe(timeframe, 
            State[state], 
            folder, 
            tag,
            os.environ["AZURE_BLOB_STORAGE_UPLOAD_CONTAINER"])

        # retrieve tags for each file
         # Initialize an empty list to hold the tags
        items = []              
        cosmos_client = CosmosClient(url=statusLog._url, credential=statusLog._key)
        database = cosmos_client.get_database_client(statusLog._database_name)
        container = database.get_container_client(statusLog._container_name)
        query_string = "SELECT DISTINCT VALUE t FROM c JOIN t IN c.tags"
        items = list(container.query_items(
            query=query_string,
            enable_cross_partition_query=True
        ))           

        # Extract and split tags
        unique_tags = set()
        for item in items:
            tags = item.split(',')
            unique_tags.update(tags)        

        
    except Exception as ex:
        log.exception("Exception in /getalluploadstatus")
        raise HTTPException(status_code=500, detail=str(ex)) from ex
    return results

@app.post("/getfolders")
async def get_folders(request: Request):
    """
    Get all folders.

    Parameters:
    - request: The HTTP request object.

    Returns:
    - results: list of unique folders.
    """
    try:
        blob_container = blob_client.get_container_client(os.environ["AZURE_BLOB_STORAGE_UPLOAD_CONTAINER"])
        # Initialize an empty list to hold the folder paths
        folders = []
        # List all blobs in the container
        blob_list = blob_container.list_blobs()
        # Iterate through the blobs and extract folder names and add unique values to the list
        for blob in blob_list:
            # Extract the folder path if exists
            folder_path = os.path.dirname(blob.name)
            if folder_path and folder_path not in folders:
                folders.append(folder_path)
    except Exception as ex:
        log.exception("Exception in /getfolders")
        raise HTTPException(status_code=500, detail=str(ex)) from ex
    return folders


@app.post("/deleteItems")
async def delete_Items(request: Request):
    """
    Delete a blob.

    Parameters:
    - request: The HTTP request object.

    Returns:
    - results: list of unique folders.
    """
    json_body = await request.json()
    full_path = json_body.get("path")
    # remove the container prefix
    path = full_path.split("/", 1)[1]
    try:
        blob_container = blob_client.get_container_client(os.environ["AZURE_BLOB_STORAGE_UPLOAD_CONTAINER"])
        blob_container.delete_blob(path)
        statusLog.upsert_document(document_path=full_path,
            status='Delete intiated',
            status_classification=StatusClassification.INFO,
            state=State.DELETING,
            fresh_start=False)
        statusLog.save_document(document_path=full_path)   

    except Exception as ex:
        log.exception("Exception in /delete_Items")
        raise HTTPException(status_code=500, detail=str(ex)) from ex
    return True


@app.post("/resubmitItems")
async def resubmit_Items(request: Request):
    """
    Resubmit a blob.

    Parameters:
    - request: The HTTP request object.

    Returns:
    - results: list of unique folders.
    """
    json_body = await request.json()
    path = json_body.get("path")
    # remove the container prefix
    path = path.split("/", 1)[1]
    try:
        blob_container = blob_client.get_container_client(os.environ["AZURE_BLOB_STORAGE_UPLOAD_CONTAINER"])
        # Read the blob content into memory
        blob_data = blob_container.download_blob(path).readall()
        # Overwrite the blob with the modified data
        blob_container.upload_blob(name=path, data=blob_data, overwrite=True)  
        # add the container to the path to avoid adding another doc in the status db
        full_path = os.environ["AZURE_BLOB_STORAGE_UPLOAD_CONTAINER"] + '/' + path
        statusLog.upsert_document(document_path=full_path,
                    status='Resubmitted to the processing pipeline',
                    status_classification=StatusClassification.INFO,
                    state=State.QUEUED,
                    fresh_start=False)
        statusLog.save_document(document_path=full_path)   

    except Exception as ex:
        log.exception("Exception in /resubmitItems")
        raise HTTPException(status_code=500, detail=str(ex)) from ex
    return True


@app.post("/gettags")
async def get_tags(request: Request):
    """
    Get all tags.

    Parameters:
    - request: The HTTP request object.

    Returns:
    - results: list of unique tags.
    """
    try:
        # Initialize an empty list to hold the tags
        items = []              
        cosmos_client = CosmosClient(url=statusLog._url, credential=statusLog._key)     
        database = cosmos_client.get_database_client(statusLog._database_name)               
        container = database.get_container_client(statusLog._container_name) 
        query_string = "SELECT DISTINCT VALUE t FROM c JOIN t IN c.tags"  
        items = list(container.query_items(
            query=query_string,
            enable_cross_partition_query=True
        ))           

        # Extract and split tags
        unique_tags = set()
        for item in items:
            tags = item.split(',')
            unique_tags.update(tags)                  
                
    except Exception as ex:
        log.exception("Exception in /gettags")
        raise HTTPException(status_code=500, detail=str(ex)) from ex
    return unique_tags

@app.post("/logstatus")
async def logstatus(request: Request):
    """
    Log the status of a file upload to CosmosDB.

    Parameters:
    - request: Request object containing the HTTP request data.

    Returns:
    - A dictionary with the status code 200 if successful, or an error
        message with status code 500 if an exception occurs.
    """
    try:
        json_body = await request.json()
        path = json_body.get("path")
        status = json_body.get("status")
        status_classification = StatusClassification[json_body.get("status_classification").upper()]
        state = State[json_body.get("state").upper()]

        statusLog.upsert_document(document_path=path,
                                  status=status,
                                  status_classification=status_classification,
                                  state=state,
                                  fresh_start=True)
        statusLog.save_document(document_path=path)

    except Exception as ex:
        log.exception("Exception in /logstatus")
        raise HTTPException(status_code=500, detail=str(ex)) from ex
    raise HTTPException(status_code=200, detail="Success")

@app.get("/getInfoData")
async def get_info_data():
    """
    Get the info data for the app.

    Returns:
        dict: A dictionary containing various information data for the app.
            - "AZURE_OPENAI_CHATGPT_DEPLOYMENT": The deployment information for Azure OpenAI ChatGPT.
            - "AZURE_OPENAI_MODEL_NAME": The name of the Azure OpenAI model.
            - "AZURE_OPENAI_MODEL_VERSION": The version of the Azure OpenAI model.
            - "AZURE_OPENAI_SERVICE": The Azure OpenAI service information.
            - "AZURE_SEARCH_SERVICE": The Azure search service information.
            - "AZURE_SEARCH_INDEX": The Azure search index information.
            - "TARGET_LANGUAGE": The target language for query terms.
            - "USE_AZURE_OPENAI_EMBEDDINGS": Flag indicating whether to use Azure OpenAI embeddings.
            - "EMBEDDINGS_DEPLOYMENT": The deployment information for embeddings.
            - "EMBEDDINGS_MODEL_NAME": The name of the embeddings model.
            - "EMBEDDINGS_MODEL_VERSION": The version of the embeddings model.
    """
    response = {
        "AZURE_OPENAI_CHATGPT_DEPLOYMENT": AZURE_OPENAI_CHATGPT_DEPLOYMENT,
        "AZURE_OPENAI_MODEL_NAME": f"{model_name}",
        "AZURE_OPENAI_MODEL_VERSION": f"{model_version}",
        "AZURE_OPENAI_SERVICE": AZURE_OPENAI_SERVICE,
        "AZURE_SEARCH_SERVICE": AZURE_SEARCH_SERVICE,
        "AZURE_SEARCH_INDEX": AZURE_SEARCH_INDEX,
        "TARGET_LANGUAGE": QUERY_TERM_LANGUAGE,
        "USE_AZURE_OPENAI_EMBEDDINGS": USE_AZURE_OPENAI_EMBEDDINGS,
        "EMBEDDINGS_DEPLOYMENT": EMBEDDING_DEPLOYMENT_NAME,
        "EMBEDDINGS_MODEL_NAME": f"{embedding_model_name}",
        "EMBEDDINGS_MODEL_VERSION": f"{embedding_model_version}",
    }
    return response


@app.get("/getWarningBanner")
async def get_warning_banner():
    """Get the warning banner text"""
    response ={
            "WARNING_BANNER_TEXT": CHAT_WARNING_BANNER_TEXT
        }
    return response

@app.get("/getMaxCSVFileSize")
async def get_max_csv_file_size():
    """Get the max csv size"""
    response ={
            "MAX_CSV_FILE_SIZE": MAX_CSV_FILE_SIZE
        }
    return response

@app.post("/getcitation")
async def get_citation(request: Request):
    """
    Get the citation for a given file

    Parameters:
        request (Request): The HTTP request object

    Returns:
        dict: The citation results in JSON format
    """
    try:
        json_body = await request.json()
        citation = urllib.parse.unquote(json_body.get("citation"))    
        blob = blob_container.get_blob_client(citation).download_blob()
        decoded_text = blob.readall().decode()
        results = json.loads(decoded_text)
    except Exception as ex:
        log.exception("Exception in /getcitation")
        raise HTTPException(status_code=500, detail=str(ex)) from ex
    return results

# Return APPLICATION_TITLE
@app.get("/getApplicationTitle")
async def get_application_title():
    """Get the application title text
    
    Returns:
        dict: A dictionary containing the application title.
    """
    response = {
            "APPLICATION_TITLE": APPLICATION_TITLE
        }
    return response

@app.get("/getalltags")
async def get_all_tags():
    """
    Get the status of all tags in the system

    Returns:
        dict: A dictionary containing the status of all tags
    """
    try:
        results = statusLog.get_all_tags()
    except Exception as ex:
        log.exception("Exception in /getalltags")
        raise HTTPException(status_code=500, detail=str(ex)) from ex
    return results

@app.get("/getTempImages")
async def get_temp_images():
    """Get the images in the temp directory

    Returns:
        list: A list of image data in the temp directory.
    """
    images = get_images_in_temp()
    return {"images": images}

@app.get("/getHint")
async def getHint(question: Optional[str] = None):
    """
    Get the hint for a question

    Returns:
        str: A string containing the hint
    """
    if question is None:
        raise HTTPException(status_code=400, detail="Question is required")

    try:
        results = generate_response(question).split("Clues")[1][2:]
    except Exception as ex:
        log.exception("Exception in /getHint")
        raise HTTPException(status_code=500, detail=str(ex)) from ex
    return results

@app.post("/posttd")
async def posttd(csv: UploadFile = File(...)):
    try:
        global dffinal
            # Read the file into a pandas DataFrame
        content = await csv.read()
        df = pd.read_csv(StringIO(content.decode('latin-1')))

        dffinal = df
        # Process the DataFrame...
        save_df(df)
    except Exception as ex:
            raise HTTPException(status_code=500, detail=str(ex)) from ex
    
    
    #return {"filename": csv.filename}
@app.get("/process_td_agent_response")
async def process_td_agent_response(retries=3, delay=1000, question: Optional[str] = None):
    if question is None:
        raise HTTPException(status_code=400, detail="Question is required")
    for i in range(retries):
        try:
            results = td_agent_response(question)
            return results
        except AttributeError as ex:
            log.exception(f"Exception in /process_tabular_data_agent_response:{str(ex)}")
            if i < retries - 1:  # i is zero indexed
                await asyncio.sleep(delay)  # wait a bit before trying again
            else:
                if str(ex) == "'NoneType' object has no attribute 'stream'":
                    return ["error: Csv has not been loaded"]
                else:
                    raise HTTPException(status_code=500, detail=str(ex)) from ex
        except Exception as ex:
            log.exception(f"Exception in /process_tabular_data_agent_response:{str(ex)}")
            if i < retries - 1:  # i is zero indexed
                await asyncio.sleep(delay)  # wait a bit before trying again
            else:
                raise HTTPException(status_code=500, detail=str(ex)) from ex

@app.get("/getTdAnalysis")
async def getTdAnalysis(retries=3, delay=1, question: Optional[str] = None):
    global dffinal
    if question is None:
            raise HTTPException(status_code=400, detail="Question is required")
        
    for i in range(retries):
        try:
            save_df(dffinal)
            results = td_agent_scratch_pad(question, dffinal)
            return results
        except AttributeError as ex:
            log.exception(f"Exception in /getTdAnalysis:{str(ex)}")
            if i < retries - 1:  # i is zero indexed
                await asyncio.sleep(delay)  # wait a bit before trying again
            else:
                if str(ex) == "'NoneType' object has no attribute 'stream'":
                    return ["error: Csv has not been loaded"]
                else:
                    raise HTTPException(status_code=500, detail=str(ex)) from ex
        except Exception as ex:
            log.exception(f"Exception in /getTdAnalysis:{str(ex)}")
            if i < retries - 1:  # i is zero indexed
                await asyncio.sleep(delay)  # wait a bit before trying again
            else:
                raise HTTPException(status_code=500, detail=str(ex)) from ex

@app.post("/refresh")
async def refresh():
    """
    Refresh the agent's state.

    This endpoint calls the `refresh` function to reset the agent's state.

    Raises:
        HTTPException: If an error occurs while refreshing the agent's state.

    Returns:
        dict: A dictionary containing the status of the agent's state.
    """
    try:
        refreshagent()
    except Exception as ex:
        log.exception("Exception in /refresh")
        raise HTTPException(status_code=500, detail=str(ex)) from ex
    return {"status": "success"}

@app.get("/getSolve")
async def getSolve(question: Optional[str] = None):
   
    if question is None:
        raise HTTPException(status_code=400, detail="Question is required")

    try:
        results = process_agent_scratch_pad(question)
    except Exception as ex:
        log.exception("Exception in /getSolve")
        raise HTTPException(status_code=500, detail=str(ex)) from ex
    return results


@app.get("/stream")
async def stream_response(question: str):
    try:
        stream = stream_agent_responses(question)
        return StreamingResponse(stream, media_type="text/event-stream")
    except Exception as ex:
        log.exception("Exception in /stream")
        raise HTTPException(status_code=500, detail=str(ex)) from ex

@app.get("/tdstream")
async def td_stream_response(question: str):
    save_df(dffinal)
    

    try:
        stream = td_agent_scratch_pad(question, dffinal)
        return StreamingResponse(stream, media_type="text/event-stream")
    except Exception as ex:
        log.exception("Exception in /stream")
        raise HTTPException(status_code=500, detail=str(ex)) from ex




@app.get("/process_agent_response")
async def stream_agent_response(question: str):
    """
    Stream the response of the agent for a given question.

    This endpoint uses Server-Sent Events (SSE) to stream the response of the agent. 
    It calls the `process_agent_response` function which yields chunks of data as they become available.

    Args:
        question (str): The question to be processed by the agent.

    Yields:
        dict: A dictionary containing a chunk of the agent's response.

    Raises:
        HTTPException: If an error occurs while processing the question.
    """
    # try:
    #     def event_stream():
    #         data_generator = iter(process_agent_response(question))
    #         while True:
    #             try:
    #                 chunk = next(data_generator)
    #                 yield chunk
    #             except StopIteration:
    #                 yield "data: keep-alive\n\n"
    #                 time.sleep(5)
    #     return StreamingResponse(event_stream(), media_type="text/event-stream")
    if question is None:
        raise HTTPException(status_code=400, detail="Question is required")

    try:
        results = process_agent_response(question)
    except Exception as e:
        print(f"Error processing agent response: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    return results


@app.get("/getFeatureFlags")
async def get_feature_flags():
    """
    Get the feature flag settings for the app.

    Returns:
        dict: A dictionary containing various feature flags for the app.
            - "ENABLE_WEB_CHAT": Flag indicating whether web chat is enabled.
            - "ENABLE_UNGROUNDED_CHAT": Flag indicating whether ungrounded chat is enabled.
            - "ENABLE_MATH_ASSISTANT": Flag indicating whether the math assistant is enabled.
            - "ENABLE_TABULAR_DATA_ASSISTANT": Flag indicating whether the tabular data assistant is enabled.
            - "ENABLE_MULTIMEDIA": Flag indicating whether multimedia is enabled.
    """
    response = {
        "ENABLE_WEB_CHAT": ENABLE_WEB_CHAT,
        "ENABLE_UNGROUNDED_CHAT": ENABLE_UNGROUNDED_CHAT,
        "ENABLE_MATH_ASSISTANT": ENABLE_MATH_ASSISTANT,
        "ENABLE_TABULAR_DATA_ASSISTANT": ENABLE_TABULAR_DATA_ASSISTANT,
        "ENABLE_MULTIMEDIA": ENABLE_MULTIMEDIA,
    }
    return response

app.mount("/", StaticFiles(directory="static"), name="static")

if __name__ == "__main__":
    log.info("IA WebApp Starting Up...")
    app.run(threaded=True)
