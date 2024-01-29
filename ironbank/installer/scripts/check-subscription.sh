echo "Check Subscription"

export CURRENT_SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo -e "Using subscription id $CURRENT_SUBSCRIPTION_ID"

# If the ARM_SUBSCRIPTION_ID is set, compare it with the 
if [ -n "$ARM_SUBSCRIPTION_ID" ] && [ $CURRENT_SUBSCRIPTION_ID != "$ARM_SUBSCRIPTION_ID" ]
then
    echo -e "*** INCORRECT SUBSCRIPTION ***."
    echo -e "Either use subscription id $ARM_SUBSCRIPTION_ID, or unset the ARM_SUBSCRIPTION_ID environment variable in your .env"
    exit 1
fi
