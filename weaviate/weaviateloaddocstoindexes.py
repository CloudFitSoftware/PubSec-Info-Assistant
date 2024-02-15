"""
This module loads documents to indexes in Weaviate.
"""

import os

from langchain.retrievers.weaviate_hybrid_search import WeaviateHybridSearchRetriever
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.document_loaders import AsyncHtmlLoader
from langchain_community.document_transformers import Html2TextTransformer

import weaviate

# running at http://localhost:8080/v1
# DEFAULT VALUE - running from weaviate-server\docker-compose.yml
weaviate_url = os.environ.get("WEAVIATE_URL", "http://localhost:8080")

client = weaviate.Client(weaviate_url)

# delete all in the vector store
# comment-out to erase everything
# client.schema.delete_all()

def load_docs_from_file(file_path):
    """
    Load data from a file containing URLs.

    Args:
        file_path (str): The path to the file containing URLs.

    Returns:
        list: A list of transformed documents.

    """
    # Initialize an empty list to store URLs
    urls = []

    # Open the file and read each line
    with open(file_path, 'r', encoding='utf-8') as file:
        for line in file:
            # Strip newline characters and add to the list
            urls.append(line.strip())

    loader = AsyncHtmlLoader(urls)
    html_docs = loader.load()

    html2text = Html2TextTransformer()
    data = html2text.transform_documents(html_docs)
    return data

def chunk_documents(docs):
    """
    Split the given documents into smaller chunks.

    Args:
        docs (list): The list of documents to be chunked.

    Returns:
        list: The list of chunked documents.
    """
    # Split docs
    text_splitter = RecursiveCharacterTextSplitter(chunk_size=750, chunk_overlap=0)
    docs = text_splitter.split_documents(docs)
    return docs

def create_index(index_name, docs, weaviate_client):
    """
    Creates an index in Weaviate with the specified name and configures it for text-based retrieval.

    Args:
        index_name (str): The name of the index to be created.
        docs (list): The list of documents to be indexed.
        weaviate_client (weaviate.client.Client): The Weaviate client.

    Returns:
        None
    """
    weaviate_client.schema.delete_class(index_name)

    class_obj = {
                    "class": index_name,
                    "vectorizer": "text2vec-transformers",
                    "moduleConfig": {
                        "reranker-transformers": {
                            "model": "cross-encoder-ms-marco-MiniLM-L-6-v2",
                        }
                    },
                }
    weaviate_client.schema.create_class(class_obj)

    retriever = WeaviateHybridSearchRetriever(
                    client=weaviate_client,
                    index_name=index_name,
                    text_key="text",
                    k=10,
                    alpha=0.50,
                    attributes=[],
                    create_schema_if_missing=True,
                )

    all_splits = chunk_documents(docs)

    retriever.add_documents(all_splits)

    print(f'Created index {index_name}')

if __name__ == '__main__':
    # Define the directory path
    DIRECTORY_PATH = "weaviate/data-urls"

    # List all files in the directory
    url_files = os.listdir(DIRECTORY_PATH)

    # Filter and display .txt files without the extension
    file_names = []
    for url_file in url_files:
        if url_file.endswith('.txt'):
            print(os.path.splitext(url_file)[0])
            file_names.append(os.path.splitext(url_file)[0])

    for file_name in file_names:
        # Data to load into vector db
        # Load from local file
        # swap this load out for your own data
        text_docs = load_docs_from_file(f'{DIRECTORY_PATH}/{file_name}.txt')

        # Create the weaviate index running in the docker container
        create_index(file_name, text_docs, client)
    