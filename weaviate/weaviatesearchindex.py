"""
This module provides functionality for searching the Weaviate index.
"""

import os

import weaviate

# REPLACE WITH YOUR QUERY
# query = str(input("Enter your query: "))
query = "What is hybrid search?"

# running at http://localhost:8080/v1
# DEFAULT VALUE - running from weaviate-server\docker-compose.yml
weaviate_url = os.environ.get("WEAVIATE_URL", "http://localhost:8080")
WEAVIATE_INDEX_NAME = os.environ.get("WEAVIATE_INDEX", "WEAVIATE")

# Step 2: Connect to a Weaviate Instance
client = weaviate.Client(weaviate_url)  # Replace with your Weaviate instance URL

# hybrid search
response = (
    client.query
    .get(WEAVIATE_INDEX_NAME, ["text", "source", "title",  "language"])
    .with_hybrid(
        query=query,
        # to adjusts the hybrid weights
        # alpha = 0 (all sparse/keyword), alpha = 1 (all dense/semantic)
        # alpha = 0.5 (equal weight for sparse and dense)
        # alpha=0.5,
    )
    .with_additional("score") # "explainScore"
    # SBERT https://github.com/UKPLab/sentence-transformers/tree/master/examples/training/ms_marco
    .with_additional('rerank(property: "text") { score }')
    .with_limit(10) # take the top 10 results prior to reranking
    .do()
)


# print(json.dumps(response, indent=2))

results = response['data']['Get'][WEAVIATE_INDEX_NAME]

print("Query Results:")
output = []
for result in results:
    print(result)
    text = result['text']
    title = result['title']
    source = result['source']
    score = result['_additional']['score']
    rerank_score = result['_additional']['rerank'][0]['score']
    output.append([source, title, text, score, rerank_score])

print(output[0])

# further filter another top-k after reranking
filtered_output = output[:3]  # Filter the first 3 items

print(filtered_output)
