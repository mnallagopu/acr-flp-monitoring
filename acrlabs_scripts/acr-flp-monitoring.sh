#!/bin/bash

## script name: acr-flp-networking.sh
## Set of tools to deploy ACR Troubleshooting Labs

## "-l|--lab" Lab scenario to deploy
## "-r|--region" region to deploy the resources
## "-u|--user" User alias to add on the lab name
## "-h|--help" help info
## "--version" print version

## read the options
TEMP=`getopt -o g:n:l:r:u:e:h:v --long resource-group:,name:,lab:,region:,user:,emailid:,tag:,help,validate,version -n 'myacrlab.sh' -- "$@"`
eval set -- "$TEMP"

## set an initial value for the flags
ACR_RG_NAME=""
ACR_NAME=""
LAB_SCENARIO=""
USER_ALIAS=""
ACR_RG_LOCATION="westeurope"

ACR_LAWS_NAME=""
TAG_NAME="ACRLAB=MONITORING"
ACR_AG_NAME=""
EMAIL_ID=""

VALIDATE=0
HELP=0
VERSION=0

while true ;
do
    case "$1" in
        -h|--help) HELP=1; shift;;
        -g|--resource-group) case "$2" in
            "") shift 2;;
            *) ACR_RG_NAME="$2"; shift 2;;
            esac;;
        -n|--name) case "$2" in
            "") shift 2;;
            *) ACR_NAME="$2"; shift 2;;
            esac;;
        -l|--lab) case "$2" in
            "") shift 2;;
            *) LAB_SCENARIO="$2"; shift 2;;
            esac;;
        -r|--region) case "$2" in
            "") shift 2;;
            *) ACR_RG_LOCATION="$2"; shift 2;;
            esac;;
        -u|--user) case "$2" in
            "") shift 2;;
            *) USER_ALIAS="$2"; shift 2;;
            esac;;
        -e|--emailid) case "$2" in
            "") shift 2;;
            *) EMAIL_ID="$2"; shift 2;;
            esac;;
        --tag) case "$2" in
            "") shift 2;;
            *) TAG_NAME="$2"; shift 2;;
            esac;; 
        -v|--validate) VALIDATE=1; shift;;
        --version) VERSION=1; shift;;
        --) shift ; break ;;
        *) echo -e "Error: invalid argument\n" ; exit 3 ;;
    esac
done

#########################
#########################
## Funtion definitions ##
#########################
#########################

##########################
## Usage text 
##########################
function print_usage_text () {
    NAME_EXEC="acr-flp-monitoring"
    echo -e "$NAME_EXEC usage: $NAME_EXEC -l <LAB#> -u <USER_ALIAS> [-v|--validate] [-r|--region] [-h|--help] [--version]\n"
    echo -e "Example with mandatory options for lab 1 and user xpto: acr-flp-monitoring -l 1 -u xpto\n"
    echo -e "\n"
    echo -e "Example with more option like location and resource group: acr-flp-monitoring -l 1 -u xpto -r westeurope -g rg-acr-flp-monitoring-lab1\n"
    echo -e "\n"
    echo -e "\nHere is the list of current labs available:\n
*************************************************************************************
CORE LABS:
*\t 1. ACR Monitoring - Alerts

*************************************************************************************\n"

echo -e "\nOnce you think you have solved the issue, use the validation parameter to check, example - acr-flp-monitoring -l 1 -u xpto -v:\n"
}
##########################
## az login check
##########################
function az_login_check () {
    if $(az account list 2>&1 | grep -q 'az login')
    then
        echo -e "\n--> Warning: You have to login first with the 'az login' command before you can run this lab tool\n"
        az login -o table
    fi
}
##########################
## Check Resource Group and ACR
##########################
function check_resourcegroup_cluster () {
    RG_EXIST=$(az group show -g $ACR_RG_NAME &>/dev/null; echo $?)
    if [ $RG_EXIST -ne 0 ]
    then
        echo -e "\nResource group $ACR_RG_NAME already exists...\n"
        echo -e "Please remove that one before you can proceed with the lab.\n"
    fi

    ACR_EXIST=$(az acr show -g $ACR_RG_NAME -n $ACR_NAME &>/dev/null; echo $?)
    if [ $ACR_EXIST -eq 0 ]
    then
        echo -e "\n--> Container Registry $ACR_NAME already exists...\n"
        echo -e "Please remove that one before you can proceed with the lab.\n"
        exit 5
    fi
}


##########################
## Lab scenario 1 (ACR Monitoring - Alert)
##########################
function lab_scenario_1 () {

ACR_SKU="Premium"

##Create a Resource group
echo -e "\n--> Creating resource group ${ACR_RG_NAME}...\n"
az group create --name $ACR_RG_NAME --location $ACR_RG_LOCATION -o table &>/dev/null

## Create ACR
echo -e "\n--> Creating ACR ${ACR_NAME}...\n"
az acr create \
  --resource-group $ACR_RG_NAME \
  --name $ACR_NAME \
  --sku $ACR_SKU &>/dev/null
 
 ACR_ID=$(az acr show \
    --resource-group $ACR_RG_NAME \
    --name $ACR_NAME \
    --query id --out tsv)

##Create a log analytic workspace
echo -e "\n--> Creating log analytic workspace ${ACR_LAWS_NAME}...\n"
az monitor log-analytics workspace create --resource-group $ACR_RG_NAME --workspace-name $ACR_LAWS_NAME --tags 'ACRLAB=MONITORING'

##Create Action group
echo -e "\n--> Creating Action group ${ACR_AG_NAME}...\n"
az monitor action-group create --resource-group $ACR_RG_NAME --name $ACR_AG_NAME -a email $USER_ALIAS $EMAIL_ID usecommonalertsChema --tags 'ACRLAB=MONITORING'

##Create alert
echo -e "\n--> Creating alert ${ACR_ALERT_NAME}...\n"
QUERY='ContainerRegistryLoginEvents
| where TimeGenerated > ago(1h)
| order by TimeGenerated desc'

ACR_LAWS_ID=$(az monitor log-analytics workspace show \
    --resource-group $ACR_RG_NAME \
    --workspace-name $ACR_LAWS_NAME \
    --query id --out tsv)

ACR_AG_ID=$(az monitor action-group show \
    --resource-group $ACR_RG_NAME \
    --name $ACR_AG_NAME \
    --query id --out tsv)
	
az monitor action-group show -g $ACR_RG_NAME --name AG-lab1 -o tsv --query id

az monitor scheduled-query create \
    --name "$ACR_ALERT_NAME" \
    --resource-group $ACR_RG_NAME \
    --scopes $ACR_LAWS_ID \
    --description "Test rule" \
    --action $ACR_AG_ID \
    --evaluation-frequency 1m \
    --mute-actions-duration PT30M \
    --severity 3 \
	--auto-mitigate false \
    --condition "count 'QRY1' > 0" \
    --condition-query QRY1="$QUERY" \
	--tags 'ACRLAB=MONITORING'

ACR_ALERT_ID=$(az monitor scheduled-query show\
    --resource-group $ACR_RG_NAME \
    --name $ACR_ALERT_NAME \
    --query id --out tsv)

##Login to ACR
ACRTOKEN=$(az acr login --name $ACR_NAME --expose-token --output tsv --query accessToken)
ACRloginServer=$(az acr login --name $ACR_NAME --expose-token --output tsv --query loginServer)
docker login $ACRloginServer --username 00000000-0000-0000-0000-000000000000 --password $ACRTOKEN

##List Resources created
echo -e "********************* \n
##CREATED RESOURCES DETAILS## \n 
ACR_ID=$ACR_ID \n
ACR_LAWS_ID=$ACR_LAWS_ID \n
ACR_AG_ID=$ACR_AG_ID \n
ACR_ALERT_ID=$ACR_ALERT_ID \n
ACRloginServer=$ACRloginServer \n
ACRTOKEN=$ACRTOKEN \n 
"

echo -e "##CREATED RESOURCES DETAILS \n 
ACR_NAME=$ACR_NAME \n
ACR_ID=$ACR_ID \n
ACR_LAWS_ID=$ACR_LAWS_ID \n
ACR_AG_ID=$ACR_AG_ID \n
ACR_ALERT_ID=$ACR_ALERT_ID \n
ACRloginServer=$ACRloginServer \n
ACRTOKEN=$ACRTOKEN \n 
" > /tmp/CURRENT_LAB_RESOURCES 
chmod 777 /tmp/CURRENT_LAB_RESOURCES


}

##########################
##LAB VALIDATION
##########################
function lab_scenario_1_validation () {
    . /tmp/CURRENT_LAB_RESOURCES
	VALIDATION_STATUS=$(az monitor diagnostic-settings list --resource $ACR_ID --query '[].logs[?enabled].category'| grep ContainerRegistryLoginEvents)

    if [[ "$VALIDATION_STATUS" == *"ContainerRegistryLoginEvents"* ]]; 
    then 
        docker login $ACRloginServer --username 00000000-0000-0000-0000-000000000000 --password $ACRTOKEN
        echo -e "\n\n========================================================"
        echo -e "\ndiagnostic-settings is configured!\n" 
		echo -e "\nLab Scenario: PASSED!\n" 
    else 
        echo -e "\n--> Error: Scenario $LAB_SCENARIO is still FAILED\n\n" 
        echo -e "Diagnostics-Settings needs to be configured!\n"
        echo -e "\nLab Scenario: FAILED!\n" 		
    fi  
}

#############################################################
## If -h | --help option is selected usage will be displayed
#############################################################
if [ $HELP -eq 1 ]
then
	print_usage_text
    echo -e '"-l|--lab" Lab scenario to deploy (3 possible options)
"-r|--region" region to create the resources
"--version" print version of aci-flp-labs
"-h|--help" help info\n'
	exit 0
fi

echo -e "\n--> ACR Troubleshooting Sessions
********************************************

This tool will use your default subscription to deploy the lab environments.
Verifing if you are authenticated already...\n"

# Verify az cli has been authenticated
az_login_check

#############################################################
## lab scenario has a valid option
#############################################################
if [ -z $LAB_SCENARIO ]; then
	echo -e "\n--> Error: Lab scenario value must be provided. \n"
	print_usage_text
	exit 9
fi

REG_EX="^\\b([1-2]|)\\b"

if [[ ! $LAB_SCENARIO =~ $REG_EX ]];
then
    echo -e "\n--> Error: invalid value for lab scenario '-l $LAB_SCENARIO'\nIt must be value from 1 to 2\n"
    exit 11
fi

if [ $VERSION -eq 1 ]
then
	echo -e "$SCRIPT_VERSION\n"
	exit 0
fi

if [ -z $USER_ALIAS ]; then
	echo -e "Error: User alias value must be provided. \n"
	print_usage_text
	exit 10
fi

if [[ "$ACR_RG_NAME" == "" ]]
then
  ACR_RG_NAME="rg-acr-flp-monitoring-lab$LAB_SCENARIO"
fi

if [[ "$ACR_NAME" == "" ]]
then
  ACR_NAME_RANDOM=$(shuf -er -n6 {a..z} {0..9} | paste -sd "")
  #echo "Random part: $ACR_NAME_RANDOM"
  ACR_NAME="$ACR_NAME_RANDOM"lab"$LAB_SCENARIO"
  #echo "Since ACR_NAME is Empty..."
  #echo "Final Name for ACR: $ACR_NAME"
fi

if [[ "$ACR_LAWS_NAME" == "" ]]
then
  ACR_LAWS_NAME="LAWS-lab$LAB_SCENARIO"
fi

if [[ "$ACR_AG_NAME" == "" ]]
then
  ACR_AG_NAME="AG-lab$LAB_SCENARIO"
fi

if [[ "$EMAIL_ID" == "" ]]
then
  EMAIL_ID=$(az account list -o json --query  "[].[user.name][0]"|grep @microsoft.com | tr -d \")
  echo " EMAIL_ID=$EMAIL_ID"
fi

if [[ "$ACR_ALERT_NAME" == "" ]]
then
  ACR_ALERT_NAME="ALERT-lab$LAB_SCENARIO"
fi

echo -e " HELP:$HELP\n ACR_RG_NAME:$ACR_RG_NAME \n ACR_NAME:$ACR_NAME \n LAB_SCENARIO:$LAB_SCENARIO \n ACR_RG_LOCATION:$ACR_RG_LOCATION \n USER_ALIAS:$USER_ALIAS \n VALIDATE:$VALIDATE \n VERSION:$VERSION\n EMAIL_ID:$EMAIL_ID \n TAG_NAME:$TAG_NAME"

##########
## main ##
##########


if [ $LAB_SCENARIO -eq 1 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_1
elif [ $LAB_SCENARIO -eq 1 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_1_validation
else
    echo -e "\n--> Error: no valid option provided\n"
    exit 12
fi


exit 0
