# Define a list of dictionaries for models
models = [
    {"friendly_name": "orca", "short_name": "Orca-2-7b", "vendor_name": "microsoft"},
    {"friendly_name": "phi2", "short_name": "phi-2", "vendor_name": "microsoft"},
    {"friendly_name": "dollyv2", "short_name": "dolly-v2-3b", "vendor_name": "databricks"},
    {"friendly_name": "falcon-40b-instruct", "short_name": "falcon-40b-instruct", "vendor_name": "tiiuae"},
    {"friendly_name": "falcon-7b", "short_name": "falcon-7b", "vendor_name": "tiiuae"},
    {"friendly_name": "falcon-7b-instruct", "short_name": "falcon-7b-instruct", "vendor_name": "tiiuae"},
    {"friendly_name": "mixstral", "short_name": "Mixtral-8x7B-Instruct-v0.1", "vendor_name": "mistralai"},
    {"friendly_name": "mistral", "short_name": "Mistral-7B-Instruct-v0.2", "vendor_name": "mistralai"},
]

def get_model_short_name(friendly_name):
    model_info = next((model for model in models if model['friendly_name'] == friendly_name), None)
    if model_info:
        return model_info['short_name']
    else:
        return None  # Handle case where friendly_name is not found
