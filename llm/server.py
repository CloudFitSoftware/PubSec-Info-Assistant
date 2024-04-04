from flask import Flask, request, jsonify
from flask_cors import CORS
from transformers import AutoTokenizer, AutoModelForCausalLM
import transformers
from instruct_pipeline import InstructionTextGenerationPipeline
import logging
import os
import sys
from model_config import get_model_short_name
import torch

MODEL_NAME = os.getenv("MODEL_NAME", "falcon-7b-instruct").lower()

model_short_name = get_model_short_name(MODEL_NAME).lower()
# Check if a command line argument is provided for the model name
## commenting this out as it doesn't work with gunicorn
# if len(sys.argv) > 1:
#     model_short_name = get_model_short_name(sys.argv[1])  # Use the first command line argument as the model name


MAX_TOKEN_RESPONSE = int(os.getenv("MAX_TOKEN_RESPONSE", "255"))
TEMPERATURE = float(os.getenv("TEMPERATURE", "0.7"))
TOP_K = int(os.getenv("TOP_K","50"))
TOP_P = float(os.getenv("TOP_P", "0.95"))
LOG_RESPONSES = os.getenv("LOG_RESPONSES", "True").lower() == "true"
print(f"Using Model: {model_short_name}")

logging.basicConfig(level=logging.DEBUG, format='%(asctime)s %(levelname)s:%(message)s')

# setting device on GPU if available, else CPU
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print('Using device:', device)
print()

#Additional Info when using cuda
if device.type == 'cuda':
    print(torch.cuda.get_device_name(0))
    print('Memory Usage:')
    print('Allocated:', round(torch.cuda.memory_allocated(0)/1024**3,1), 'GB')
    print('Cached:   ', round(torch.cuda.memory_reserved(0)/1024**3,1), 'GB')

app = Flask(__name__)
CORS(app)  # Enable CORS

# Load the model from the local directory
try:
    logging.info("Loading tokenizer")
    tokenizer = AutoTokenizer.from_pretrained(f"./models/{model_short_name.lower()}/")
    logging.info("Done loading tokenizer")
    logging.info("Loading Model for LM")
    model = transformers.pipeline("text-generation", 
                                  model=f"./models/{model_short_name.lower()}/", 
                                  tokenizer=tokenizer, 
                                  torch_dtype=torch.bfloat16, 
                                  trust_remote_code=False, 
                                  device=device.type,
                                  truncation=True,)
    logging.info("Done loading Model for LM.")
except Exception as e:
    logging.error(f"Error loading model: {e}")
    logging.info(f"Error loading model: {e}. \n Please ensure the model is downloaded and saved to the models directory.")

def get_response_from_model(model_name: str, user_request: str, input_data):
    response = None
    logging.info(f"Running {model_name} with request: {request.json}")

    if(model_name == "phi-2"):
        input_data = request.json
        inputs = tokenizer(user_request, return_tensors='pt')
        outputs = model.generate(inputs['input_ids'], max_length=MAX_TOKEN_RESPONSE)
        response = tokenizer.decode(outputs[0], skip_special_tokens=True)
    elif(model_name == "dolly-v2-3b"):
        generate_text = InstructionTextGenerationPipeline(model=model, tokenizer=tokenizer)
        response = generate_text(user_request)
    elif("falcon" in model_name):
        generate_text = model(
            user_request,
            max_length=10000,
            do_sample=True,
            top_k=10,
            num_return_sequences=1,
            eos_token_id=tokenizer.eos_token_id,
        )
        response = generate_text
    elif("mistral" in model_name):
        generate_text = model(
            user_request,
            max_length=10000,
            max_new_tokens=500,
            do_sample=True,
            top_k=50,
            num_return_sequences=1,
            eos_token_id=tokenizer.eos_token_id,
            temperature=.03,
        )
        response = generate_text     
    for seq in generate_text:
        print(f"Result: {seq['generated_text']}")

    if LOG_RESPONSES:
        logging.info(f"Response from {model_name}: {response}")
    else:
        logging.info(f"Response from {model_name} not logged.")

    return jsonify(response)

@app.route('/predict', methods=['POST', 'GET'])
def predict():
    input_data = request.json
    user_request = input_data['text']
    logging.info(f"Running predict() with request: {request.json}")
    try:
        response = get_response_from_model(model_short_name, user_request, input_data)
    except RuntimeError as e:  # Catching RuntimeError
        if "CUDA out of memory" in str(e):  # Check if error message is about CUDA OOM
            torch.cuda.empty_cache()  # Attempt to clear CUDA cache
            logging.error("CUDA out of memory error encountered. Attempting to clear cache.")
            response = ["Error: Device out of memory"]
        else:
            response = get_response_from_model(model_short_name, user_request, input_data)
    return response

@app.route('/test', methods=['POST', 'GET'])
def test():
    return jsonify({"response": "Hello World!"})

if __name__ == '__main__':
    app.run(debug=False, port="6001")
