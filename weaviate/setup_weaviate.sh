#!/bin/bash

# Create Docker network
docker network create weaviate_network

# Build Docker images
docker build -f Dockerfile.weaviate -t weaviate_image .
docker build -f Dockerfile.t2v-transformers -t t2v_transformers_image .
docker build -f Dockerfile.reranker-transformers -t reranker_transformers_image .

# Run Docker containers
docker run -d --name weaviate --network weaviate_network -p 8080:8080 -p 50051:50051 -v weaviate_data:/var/lib/weaviate weaviate_image
docker run -d --name t2v-transformers --network weaviate_network t2v_transformers_image
docker run -d --name reranker-transformers --network weaviate_network reranker_transformers_image