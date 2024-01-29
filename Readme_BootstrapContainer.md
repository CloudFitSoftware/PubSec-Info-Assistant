# Installing via Container

This method is intended to be run as a run-once bootstrapper to help enable OpenAI in Microsoft Azure Government.  

The purpose of this container is to have the existing PubSec-Info-Assistant solution to be submited, scanned, and approved for the IronBank.

## How-To
**Note**: Until there is a landing zone at the IronBank, the current container registry is located internally at CloudFit.  This will not be exposed for public consumption, unless exceptions are in place.  As the PubSec-Info-Assistant is now a public and open source repo, if IB is not a requirement, it can be installed from the repo.

**Note:** While this works on Windows, all examples are done for Linux distros

1. Pull down the container locally (you may need to authenticate with `az acr login`)
   
   **Note** When this is in IronBank, this reference will be different
   
   `docker pull cloudfitglpoc.azurecr.io/info-asst-installer:0.4`

1. Create a local working directory and sub directories

   ```bash 
   mkdir -p /tmp/info-asst/.state/
   ```

1. Create `local.env` by running: 

   **Note:** This file will be a part of IronBank / Platform One repo

   ```bash
   touch /tmp/info-asst/local.env
   ```

1. Copy the following contents into `local.env` and update values

   **Note:** This file will be a part of IronBank / Platform One repo

   ```bash
   #Values that are required below are marked accordingly. Depending on your selections additional values may be required. 
   # Please see our deployment guide for more information at ./docs/deployment/deployment.md#configure-env-files

   # Region to deploy into when running locally.
   # This is set by the Azure Pipeline for other environments.
   export LOCATION="westeurope" # Required
   export WORKSPACE="myworkspace" # Required
   export SUBSCRIPTION_ID="" # Required
   export TENANT_ID="" # Required
   export IS_USGOV_DEPLOYMENT=true # Required

   # Use this setting to determine whether a user needs to be granted explicit access to the website via an
   # Azure AD Enterprise Application membership (true) or allow the website to be available to anyone in the Azure tenant (false). Defaults to false.
   # If set to true, A tenant level administrator will be required to grant the implicit grant workflow for the Azure AD App Registration manually.
   export REQUIRE_WEBSITE_SECURITY_MEMBERSHIP=false # Required

   # Uncomment this if you want to avoid the "are you sure?" prompt when applying TF changes
   # export SKIP_PLAN_CHECK=1

   # If using an existing deployment of Azure OpenAI, set the USE_EXISTING_AOAI to true and fill in the following values.  This value must be set to true if deploying this solution to AzureUSGovernment
   export USE_EXISTING_AOAI=true # Required
   export AZURE_OPENAI_RESOURCE_GROUP=""
   export AZURE_OPENAI_SERVICE_NAME=""
   export AZURE_OPENAI_SERVICE_KEY=""
   export AZURE_OPENAI_CHATGPT_DEPLOYMENT=""

   # Choose your preferred text embedding model from below options of closed source and open source models.:
   # 1. Azure OpenAI Embeddings 
   # 2. sentence-transformers/all-mpnet-base-v2                      768
   # 3. BAAI/bge-small-en-v1.5                                       384
   # 4. For embedding in languages other than English:
   #    sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2  384


   # To use Azure OpenAI Embeddings, set the following properties:
   export USE_AZURE_OPENAI_EMBEDDINGS=true # Required
   export AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME="text-embedding-ada-002"

   # If you prefer an open-source Embedding model, use below section to set your preferred model:

   #-----------------------------------------------------------------------------------------------#
   # export USE_AZURE_OPENAI_EMBEDDINGS=false
   # export AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME="text-embedding-ada-002"

   #And choose one of your preferred open-source embedding models below. You only need to uncomment one from below.

   # Uncomment and set the desired model and vector size:
   # export OPEN_SOURCE_EMBEDDING_MODEL="BAAI/bge-small-en-v1.5"
   # export OPEN_SOURCE_EMBEDDING_MODEL_VECTOR_SIZE="384"

   # Uncomment and set the desired model and vector size:
   # export OPEN_SOURCE_EMBEDDING_MODEL="sentence-transformers/all-mpnet-base-v2"
   # export OPEN_SOURCE_EMBEDDING_MODEL_VECTOR_SIZE="768"

   # Uncomment and set the desired model and vector size:
   # export OPEN_SOURCE_EMBEDDING_MODEL="sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
   # export OPEN_SOURCE_EMBEDDING_MODEL_VECTOR_SIZE="384"



   #-------------------------------------------------------------------------------------------------#

   # If you are doing a deployment where any of the following are true...
   # 1. Azure OpenAI models are limited in your region
   # 2. Azure OpenAI is not in the same Subscription as your current target subscription
   # 3. You are deploying to USGov with Azure OpenAI in Azure Commercial
   # ...then you will need to set the following values to the Azure OpenAI model you want to use. 
   export AZURE_OPENAI_CHATGPT_MODEL_NAME=""
   export AZURE_OPENAI_CHATGPT_MODEL_VERSION=""
   export AZURE_OPENAI_EMBEDDINGS_MODEL_NAME=""
   export AZURE_OPENAI_EMBEDDINGS_MODEL_VERSION=""
   #-------------------------------------------------------------------------------------------------#

   # If you have limited capacity in your subscription, you can set the following to limit the deployment capacity.
   export AZURE_OPENAI_CHATGPT_MODEL_CAPACITY="240" # Required

   # If your deployment requires a warning banner and footer, please set this variable.
   export CHAT_WARNING_BANNER_TEXT=""

   # A pointer to a supported language ENV file located in the ./languages folder.
   export DEFAULT_LANGUAGE="en-US" # Required

   # If you are deploying this for a customer, you can optionally set the following values to track usage of the accelerator.
   # This uses the pattern of Customer Usage Attribution, more info can be found at https://learn.microsoft.com/en-us/partner-center/marketplace/azure-partner-customer-usage-attribution 
   export ENABLE_CUSTOMER_USAGE_ATTRIBUTION=true
   export CUSTOMER_USAGE_ATTRIBUTION_ID="7a01ff74-15c2-4fec-9f14-63db7d3d6131"

   # Enable capabilities under development. This should be set to false
   export ENABLE_DEV_CODE=false

   # Branding
   # Leave application title blank for the default name
   export APPLICATION_TITLE=""
   ```

1. To run through the installation, execute the following command

   ```bash 
   docker run -v /tmp/info-asst/local.env:/info-asst/environments/local.env -v /tmp/info-asst/.state/:/info-asst/.state/ bootstrap
   ```

## Additional Comments

The installer container is currently built via an internal CF ADO pipeline.  Any updates to the code base or referenced containers will require a manual run of this pipeline.
