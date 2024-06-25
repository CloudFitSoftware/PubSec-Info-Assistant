import msal
from fastapi import APIRouter, Request, HTTPException
from fastapi.responses import RedirectResponse
from azure.identity import AzureAuthorityHosts
import os

#### ENV VARS ##########################

# AZURE_AUTHORITY_HOST = os.environ.get("AZURE_AUTHORITY_HOST") or "AzureCloud"
CLIENT_ID = os.environ.get("ENTRA_ID_CLIENT_ID")
CLIENT_SECRET = os.environ.get("ENTRA_ID_CLIENT_SECRET")
TENANT_ID = os.environ.get("AZURE_TENANT_ID")
APP_DOMAIN = os.environ.get("APP_DOMAIN")
AUTHORITY_HOST = os.environ.get("AZURE_OPENAI_AUTHORITY_HOST") or "AzureCloud"

if AUTHORITY_HOST == "AzureUSGovernment":
    AUTHORITY = AzureAuthorityHosts.AZURE_GOVERNMENT
else:
    AUTHORITY = AzureAuthorityHosts.AZURE_PUBLIC_CLOUD

AUTHORITY = f"https://{AUTHORITY}/{TENANT_ID}"

#########################################

router = APIRouter()

redirect_uri = f"{APP_DOMAIN}/auth/callback"
scope = ["User.Read"]

msal_app = msal.ConfidentialClientApplication(
    CLIENT_ID,
    authority=AUTHORITY,
    client_credential=CLIENT_SECRET,
)

@router.get("/login")
async def login():
    auth_url = msal_app.get_authorization_request_url(scope, redirect_uri=redirect_uri)
    return RedirectResponse(auth_url)

@router.get("/callback")
async def callback(request: Request):
    code = request.query_params.get("code")
    if not code:
        raise HTTPException(status_code=400, detail="Authorization code not found")
    
    result = msal_app.acquire_token_by_authorization_code(
        code,
        scopes=scope,
        redirect_uri=redirect_uri,
    )
    
    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error_description"])
    
    account = result.get("id_token_claims", {})
    access_token = result.get("access_token")

    # Store the access token in a cookie
    response = RedirectResponse(url="/home")
    response.set_cookie(key="access_token", value=access_token, httponly=True,secure=True)
    response.set_cookie(key="account", value=account, httponly=True, secure=True)
    
    return response

@router.get("/logout")
async def logout(request: Request):
    response = RedirectResponse(url="/")
    response.delete_cookie("access_token")
    response.delete_cookie("account")
    return response

EXCLUDE_PATHS = {"/auth/login", "/auth/callback", "/auth/logout"}

def get_current_user(request: Request):
    if request.url.path not in EXCLUDE_PATHS:
        token = request.cookies.get("access_token")
        account = request.cookies.get("account")
        if not token or not account:
            raise HTTPException(status_code=401, detail="User not authenticated")

        accounts = msal_app.get_accounts()
        if not accounts:
            raise HTTPException(status_code=401, detail="User not authenticated")

        result = msal_app.acquire_token_silent(scope, account=accounts[0])
        if not result:
            raise HTTPException(status_code=401, detail="Invalid token")

        return result
    return None