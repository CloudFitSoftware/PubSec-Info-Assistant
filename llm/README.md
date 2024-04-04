## OSS SLM Server
This project lets you use a Small Language Model (SLM), called [Microsoft Phi-2](https://www.microsoft.com/en-us/research/blog/phi-2-the-surprising-power-of-small-language-models/) (or any other Huggingface model), from a local repository. The project includes an app to download the model and a language server to use it. It then lets you expose an endpoint (using Flask as the webserver) so you can use the SLM like an API, just as you would with a cloud-based model, and build apps around it.

### Setup
1. Clone the repository
2. Install the requirements
3. Create a .env file, using the .env.example file as a template
4. Run `save_model.py` to download the model. This repo expects the model to be saved in the `models` folder.

```
python save_model.py tinyllama
```


Some models to try:
- Orca
friendly_name = "orca"
model_short_name = "Orca-2-7b"
model_vendor_name = "microsoft"

- TinyLlama
friendly_name = "tinyLlama"
model_short_name ="TinyLlama-1.1B-Chat-v1.0"
model_vendor_name = "TinyLlama"

- Phi-2
friendly_name = "phi-2"
model_short_name = "phi-2"
model_vendor_name = "microsoft"


5. Run `server.py` to start the language server. The default model is tinyllama:
```
python3 server.py phi2
```


### Usage
Once the language server is running, use the endpoint exposed (by default on port 6001), to hit the 'predict' endpoint.

Now you can use the language server to hit the predict endpoint, available at `/predict` on GET and POST. The endpoint expects a JSON payload with a `text` key. For example:

```
curl --location --request POST 'http://localhost:6001/predict' \
--header 'Content-Type: application/json' \
--data-raw '{"text": "Contrast the styles of Messi and Ronaldo"}'
```

#### Note
In the `.env` file, `MAX_TOKEN_RESPONSE` sets the maximum length of the response from the model. Set judiciously based upon the compute/GPU available, as longer responses will take more time, based on machine specs. Models have their own max response length, so setting it above that length will have no effect.