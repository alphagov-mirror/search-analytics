#!/bin/bash
set -e
set -o pipefail

SEARCH_NODE=$(/usr/local/bin/govuk_node_list -c search --single-node)
if [[ -z $SKIP_TRAFFIC_LOAD ]]; then
  if [ \! -d ENV ]; then virtualenv ENV; fi
  . ENV/bin/activate
  pip install -r requirements.txt
  rm -f page-traffic.dump
  PYTHONPATH=. python scripts/fetch.py page-traffic.dump 14
  ssh deploy@${SEARCH_NODE} '(cd /var/apps/rummager; govuk_setenv rummager bundle exec ./bin/page_traffic_load)' < page-traffic.dump
  ssh deploy@${SEARCH_NODE} '(cd /var/apps/rummager; govuk_setenv rummager bundle exec rake rummager:clean RUMMAGER_INDEX=page-traffic'
fi

ssh deploy@${SEARCH_NODE} '(cd /var/apps/rummager; PROCESS_ALL_DATA=true RUMMAGER_INDEX=mainstream govuk_setenv rummager bundle exec rake rummager:update_popularity)'
ssh deploy@${SEARCH_NODE} '(cd /var/apps/rummager; PROCESS_ALL_DATA=true RUMMAGER_INDEX=detailed govuk_setenv rummager bundle exec rake rummager:update_popularity)'
ssh deploy@${SEARCH_NODE} '(cd /var/apps/rummager; PROCESS_ALL_DATA=true RUMMAGER_INDEX=government govuk_setenv rummager bundle exec rake rummager:update_popularity)'
ssh deploy@${SEARCH_NODE} '(cd /var/apps/rummager; RUMMAGER_INDEX=govuk govuk_setenv rummager bundle exec rake rummager:update_popularity)'

ssh deploy@${SEARCH_NODE} '(cd /var/apps/rummager; govuk_setenv rummager bundle exec rake rummager:sync_govuk)'
