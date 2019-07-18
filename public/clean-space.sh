#!/usr/bin/env bash
#
# Script to clean up a Cloud Foundry space
#
# Neil Winton (nwinton@pivotal.io)

function main() {

  NO_EXEC=false
  DELETE_SERVICE=delete-service

  while getopts 'np' option
  do
    case $option in
      n)
        NO_EXEC=true
        ;;
      p)
        DELETE_SERVICE=purge-service-instance
        ;;
      *)
        usage
        ;;
    esac
  done

  shift $((OPTIND - 1))

  [[ $# == 2 ]] || usage

  local org=$1
  local space=$2

  perform cf target -o $org -s $space

  loadSpaceSummary $space
  unbindServicesStopAndDeleteApps
  deleteServiceKeysAndServices
  deleteRemainingRoutes $space
}

function usage() {
  cat >&2 <<EOF
Usage: $0 [-np] org space
Stops and deletes all apps and services in the given org and space.

Use the '-n' option to do a 'dry-run' showing what commands would be
executed but not actually perfoming them.

Use the '-p' option top use 'cf purge-service-instance' instead of
'cf delete-service' to remove service instances.
EOF
  exit 1
}

function perform() {
  echo $*
  $NO_EXEC || "$@"
}

function loadSpaceSummary() {
  local space=$1
  local guid=$(cf space $space --guid)
  SPACE_SUMMARY=$(cf curl /v2/spaces/$guid/summary)
}

function spaceSummary() {
  echo "$SPACE_SUMMARY"
}

function unbindServicesForApp() {
  local app="$1"
  local bound=$(spaceSummary | jq -r '.apps[] | select(.name == "'$app'") | .service_names[]')
  local service

  for service in $bound
  do
    perform cf unbind-service $app $service
  done
}

function unbindServicesStopAndDeleteApps() {
  local apps=$(spaceSummary | jq -r .apps[].name)
  local app
  echo '# apps:' $apps

  for app in $apps
  do
    unbindServicesForApp "$summary" $app
    perform cf stop $app
    perform cf delete -r -f $app
  done
}

function deleteServiceKeysAndServices() {
  local services=$(spaceSummary | jq -r .services[].name)
  local service

  echo '# services:' $services
  for service in $services
  do
    deleteKeysForService $service
    perform cf $DELETE_SERVICE -f $service
  done
}

function deleteKeysForService() {
  local service=$1
  local guid=$(spaceSummary | jq -r '.services[] | select(.name == "'$service'") | .guid')
  local keys=$(cf curl /v2/service_instances/$guid/service_keys | (jq -r '.resources[].entity.name' 2> /dev/null))
  local key

  for key in $keys
  do
    perform cf delete-service-key -f $service $key
  done
}

function deleteRemainingRoutes() {
  local space=$1
  local guid=$(cf space $space --guid)
  local route_info=$(cf curl /v2/spaces/$guid/routes?inline-relations-depth=1)
  local hosts=$(echo "$route_info" | jq -r '.resources[].entity.host')
  local host
  local domain

  echo '# routes:' $hosts
  for host in $hosts
  do
    domain=$(echo "$route_info" | jq -r '.resources[].entity | select(.host == "'$host'") | .domain.entity.name')
    perform cf delete-route -f $domain --hostname $host
  done
}

main "$@"
