# subscription name passed in from pipeline - if not, use 'local'
if [ -z "$ENVIRONMENT_NAME" ]; then
    export ENVIRONMENT_NAME="local"
fi

echo "Environment set: $ENVIRONMENT_NAME."

# Pull in variables dependent on the environment we are deploying to.
if [ -f "$ENV_DIR/environments/$ENVIRONMENT_NAME.env" ]; then
    echo "Loading environment variables for $ENVIRONMENT_NAME."
    source "$ENV_DIR/environments/$ENVIRONMENT_NAME.env"
else
    echo "Unable to find $ENV_DIR/environments/$ENVIRONMENT_NAME.env"
    echo "Ensure you have correctly mounted the local file to the container"
    exit 1
fi

# Pull in variables dependent on the Language being targeted
if [ -f "$ENV_DIR/environments/languages/$DEFAULT_LANGUAGE.env" ]; then
    echo "Loading environment variables for Language: $DEFAULT_LANGUAGE."
    source "$ENV_DIR/environments/languages/$DEFAULT_LANGUAGE.env"
else
    echo "No Language set, please check $ENVIRONMENT_NAME.env for DEFAULT_LANGUAGE"
    exit 1
fi

# Fail if the following environment variables are not set
if [[ -z $WORKSPACE ]]; then
    echo "WORKSPACE must be set."
    exit 1
elif [[ "${WORKSPACE}" =~ [[:upper:]] ]]; then
    echo "Please use a lowercase workspace environment variable between 1-15 characters. Please check 'private.env.example'"
    exit 1
fi

# Set the name of the resource group
export RG_NAME="infoasst-$WORKSPACE"

echo -e "\n\e[32m🎯 Target Resource Group: \e[33m$RG_NAME\e[0m\n"
