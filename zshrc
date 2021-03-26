# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="/home/jkiely/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# Caution: this setting can cause issues with multiline prompts (zsh 5.7.1 and newer seem to work)
# See https://github.com/ohmyzsh/ohmyzsh/issues/5765
 COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder
export GOPATH="/home/jkiely/go"
export GOBIN="/home/jkiely/go/bin"
export PATH=$PATH:/usr/local/go/bin

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
osd_get_credentials()
{
  CLUSTER_NAME=$1
  if [ $# -eq 0 ]; then
    CLUSTER_NAME=$OSD_CLUSTER_NAME
  fi

  echo "Getting credentials for $CLUSTER_NAME"
  CLUSTER=$(ocm get clusters | jq -r --arg CLUSTER_NAME "$CLUSTER_NAME" '.items[] | select(.name==$CLUSTER_NAME)')
  CLUSTER_ID=$(echo $CLUSTER | jq '.id' | tr -d '\"')
  CLUSTER_CONSOLE=$(echo $CLUSTER | jq '.console.url' | tr -d '\"')
  CLUSTER_CREDS=$(ocm get /api/clusters_mgmt/v1/clusters/$CLUSTER_ID/credentials | jq '.admin')
  echo "Console: $CLUSTER_CONSOLE"
  echo $CLUSTER_CREDS | jq
}

osd_cluster_login() {
  CLUSTER_NAME=${1}
  CLUSTER=$(ocm get clusters | jq -r --arg CLUSTER_NAME "$CLUSTER_NAME" '.items[] | select(.name==$CLUSTER_NAME)')
  CLUSTER_ID=$(echo $CLUSTER | jq '.id' | tr -d '\"')
  CLUSTER_CREDS=$(ocm get /api/clusters_mgmt/v1/clusters/$CLUSTER_ID/credentials | jq '.admin')
  CLUSTER_API=$(echo $CLUSTER | jq '.api.url' | tr -d '\"')
  CLUSTER_CONSOLE=$(echo $CLUSTER | jq '.console.url' | tr -d '\"')
  CLUSTER_LOGIN=$(echo $CLUSTER_CONSOLE |cut -d '.' -f 3,4,5,6,7 | cut -d '/' -f 1) 
  CLUSTER_PASSWORD=$(echo $CLUSTER_CREDS | jq -r .password)
  oc login -u kubeadmin -p $CLUSTER_PASSWORD --server=$CLUSTER_API
  echo "Console: $CLUSTER_CONSOLE"
  echo "Console Login: https://oauth-openshift.apps.$CLUSTER_LOGIN/login/kube:admin?then=%2Foauth%2Fauthorize%3Fclient_id%3Dconsole%26idp%3Dkubeadmin%26redirect_uri%3Dhttps%253A%252F%252Fconsole-openshift-console.apps.$CLUSTER_LOGIN%252Fauth%252Fcallback%26response_type%3Dcode%26scope%3Duser%253Afull"
  echo $CLUSTER_CREDS | jq
}

osd_login() {
  osd_cluster_login ${1}
}

aws_login() {
    AWS_ACCESS_KEY_ID=$(oc get secret aws-creds -n kube-system -o yaml | yq r - data.aws_access_key_id | base64 -d )
    AWS_SECRET_ACCESS_KEY=$(oc get secret aws-creds -n kube-system -o yaml | yq r - data.aws_secret_access_key | base64 -d )
    aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
    aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
}

osd_provision_cluster() {
   cluster_file=${1}
   COMMAND=$(ocm post /api/clusters_mgmt/v1/clusters --body=$cluster_file)
}

osd_delete_addon() {
        CLUSTER_NAME=${1}
        CLUSTER=$(ocm get clusters | jq -r --arg CLUSTER_NAME "$CLUSTER_NAME" '.items[] | select(.name==$CLUSTER_NAME)')
        CLUSTER_ID=$(echo $CLUSTER | jq '.id' | tr -d '\"')
        ocm delete /api/clusters_mgmt/v1/clusters/$CLUSTER_ID/addons/managed-api-service
}

osd_get_cluster_id(){
CLUSTER_NAME=${1}
        CLUSTER=$(ocm get clusters | jq -r --arg CLUSTER_NAME "$CLUSTER_NAME" '.items[] | select(.name==$CLUSTER_NAME)')
        CLUSTER_ID=$(echo $CLUSTER | jq '.id' | tr -d '\"')
        echo ${CLUSTER_ID}
}
mkcd ()
{
  mkdir -p -- "$1" && cd -P -- "$1"
}
ocm_hibernate(){
  # Puts an OCM cluster in hibernated state
   set -e; set -o pipefail; # Fail early
    CLUSTER_ID=$(set -e; ocm get clusters | jq ".items[] | select(.name == \"$CLUSTER_NAME\" ).id" -r)
    echo "Cluster name: ${CLUSTER_NAME}"
    echo "Cluster ID: ${CLUSTER_ID}"
    echo "Sending hibernation request"
    echo "" | ocm post "/api/clusters_mgmt/v1/clusters/${CLUSTER_ID}/hibernate"
  
}
ocm_get_cluster_id(){
  #get the id of a specified cluster
        CLUSTER_NAME=${1}
        echo $(ocm get clusters --parameter search="display_name like '%$CLUSTER_NAME%'" | jq -r '.items[].id')
}
ocm_hibernate(){
  # Puts an OCM cluster in hibernated state
   ( set -e; set -o pipefail; # Fail early
    CLUSTER_ID=$(set -e; ocm get clusters | jq ".items[] | select(.name == \"$CLUSTER_NAME\" ).id" -r)
    echo "Cluster name: ${CLUSTER_NAME}"
    echo "Cluster ID: ${CLUSTER_ID}"
    echo "Sending hibernation request"
    echo "" | ocm post "/api/clusters_mgmt/v1/clusters/${CLUSTER_ID}/hibernate"
   )
}
ocm_extend(){
  # Extends expiration_timestamp of a cluster
  ( set -e; set -o pipefail; # Fail early
    CLUSTER_NAME=${1}
    CLUSTER_ID=$( set -e; set -o pipefail; ocm get clusters | jq ".items[] | select(.name == \"$CLUSTER_NAME\" ).id" -r)
    CLUSTER_BYOC=$(ocm get "/api/clusters_mgmt/v1/clusters/${CLUSTER_ID}" | jq -r .byoc)
    if [ $CLUSTER_BYOC != 'true' ]; then
      echo "This command should be used only with BYOC / CCS clusters"
      exit 1
    fi
    echo "Existing timestamp is "
    ocm get /api/clusters_mgmt/v1/clusters/"${CLUSTER_ID}" | jq -r .expiration_timestamp
    echo -e "\nEnter new time stamp"
    read NEW_DATE
    echo "{\"expiration_timestamp\": \"$NEW_DATE\"}" | ocm patch /api/clusters_mgmt/v1/clusters/"$CLUSTER_ID"
    if [ $? -eq 0 ]; then
      echo "Cluster timestamp updated to:"
      ocm get /api/clusters_mgmt/v1/clusters/"${CLUSTER_ID}" | jq -r .expiration_timestamp
    else
      echo "Cluster timestamp update FAILED"
      exit 1
    fi
  )
}
ocm_cluster_login() {
  #Log in to a specified cluster, also provides console link and kubeadmin credentials
  CLUSTER_NAME=${1}
  CLUSTER=$(ocm get clusters | jq -r --arg CLUSTER_NAME "$CLUSTER_NAME" '.items[] | select(.name==$CLUSTER_NAME)')
  CLUSTER_ID=$(echo $CLUSTER | jq '.id' | tr -d '\"')
  CLUSTER_CREDS=$(ocm get /api/clusters_mgmt/v1/clusters/$CLUSTER_ID/credentials | jq '.admin')
  CLUSTER_API=$(echo $CLUSTER | jq '.api.url' | tr -d '\"')
  CLUSTER_CONSOLE=$(echo $CLUSTER | jq '.console.url' | tr -d '\"')
  CLUSTER_LOGIN=$(echo $CLUSTER_CONSOLE |cut -d '.' -f 3,4,5,6,7 | cut -d '/' -f 1) 
  CLUSTER_PASSWORD=$(echo $CLUSTER_CREDS | jq -r .password)
  oc login -u kubeadmin -p $CLUSTER_PASSWORD --server=$CLUSTER_API
  echo "Console: $CLUSTER_CONSOLE"
  echo "Console Login: https://oauth-openshift.apps.$CLUSTER_LOGIN/login/kube:admin?then=%2Foauth%2Fauthorize%3Fclient_id%3Dconsole%26idp%3Dkubeadmin%26redirect_uri%3Dhttps%253A%252F%252Fconsole-openshift-console.apps.$CLUSTER_LOGIN%252Fauth%252Fcallback%26response_type%3Dcode%26scope%3Duser%253Afull"
  echo $CLUSTER_CREDS | jq
}
ocm_get_credentials()
{
  #get credentials of a specified cluster: eg osd_get_credentials cluster1
  CLUSTER_NAME=$1
  if [ $# -eq 0 ]; then
    CLUSTER_NAME=$OSD_CLUSTER_NAME
  fi

  echo "Getting credentials for $CLUSTER_NAME"
  CLUSTER=$(ocm get clusters --parameter search="display_name like '$CLUSTER_NAME'" | jq -r '.items[]')
  CLUSTER_ID=$(set -e; ocm get clusters --parameter search="display_name like '$CLUSTER_NAME'" | jq -r '.items[].id')
  CLUSTER_CONSOLE=$(echo $CLUSTER | jq '.console.url' | tr -d '\"')
  CLUSTER_CREDS=$(ocm get /api/clusters_mgmt/v1/clusters/$CLUSTER_ID/credentials | jq '.admin')
  echo "Console: $CLUSTER_CONSOLE"
  echo $CLUSTER_CREDS | jq
}
mkcd()
{
mkdir $1
cd $1
}

ocm_clusterstoragetrue()
{
oc patch rhmi rhoam -n redhat-rhoam-operator --type=merge -p '{"spec":{"useClusterStorage": "true" }}'
}
