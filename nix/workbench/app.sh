usage_app() {
     usage "app" "Multi-container application" <<EOF
    compose               Multi-container description file

EOF
}

app() {
  local op=${1:-show}; test $# -gt 0 && shift

  case "$op" in

    # wb app compose $WORKBENCH_SHELL_PROFILE_DIR/{profile,node-specs}.json name tag
    compose )
      # jq 'keys|.[]' --raw-output $WORKBENCH_SHELL_PROFILE_DIR/node-specs.json
      local usage="USAGE: wb app $op PROFILE-NAME/JSON NODE-SPECS/JSON NODE_IMAGE_NAME NODE_IMAGE_TAG TRACER_IMAGE_NAME TRACER_IMAGE_TAG"
      local profile=${1:?$usage}
      local nodespecs=${2:?$usage}
      local nodeImageName=${3:?$usage}
      local nodeImageTag=${4:?$usage}
      local tracerImageName=${5:?$usage}
      local tracerImageTag=${6:?$usage}

      # Hack
      global_rundir_def=$PWD/run

      yq --yaml-output "{
        services: (
          (
              .
            | with_entries(
                {
                    key: .key
                  , value: {
                        container_name: \"\(.value.name)\"
                      , pull_policy: \"never\"
                      , image: \"$nodeImageName:$nodeImageTag\"
                      , networks: {
                          \"cardano-node-network\": {
                            ipv4_address: \"172.22.\(.value.i / 254 | floor).\(.value.i % 254 + 1)\"
                          }
                        }
                      , ports: [\"\(.value.port):\(.value.port)\"]
                      , volumes: [
                            \"SHARED:/var/cluster\"
                          , \"NODE-\(.value.name):/var/cardano-node\"
                          , \"TRACER:/var/cardano-tracer\"
                        ]
                      , environment: [

                            \"HOST_ADDR=172.22.\(.value.i / 254 | floor).\(.value.i % 254 + 1)\"
                          , \"PORT=\(.value.port)\"
                          , \"SOCKET_PATH=/var/cardano-node/node.socket\"
                          , \"TRACER_SOCKET_PATH=/var/cardano-tracer/tracer.socket\"

                          , \"DATA_DIR=/var/cardano-node\"
                          #, \"NODE_CONFIG=/var/cardano-node/config.json\"
                          , \"NODE_CONFIG=/var/cluster/node-\(.value.i)/config.json\"
                          , \"NODE_TOPOLOGY=/var/cardano-node/topology.json\"

                          #, \"SHELLEY_GENESIS_FILE=/var/cluster/genesis-shelley.json\"
                          #, \"BYRON_GENESIS_FILE=/var/cluster/genesis/byron/genesis.json\"
                          #, \"ALONZO_GENESIS_FILE=/var/cluster/genesis/genesis.alonzo.json\"

                          , \"SHELLEY_KES_KEY=/var/cluster/genesis/node-keys/node-kes\(.value.i).skey\"
                          , \"SHELLEY_VRF_KEY=/var/cluster/genesis/node-keys/node-vrf\(.value.i).skey\"
                          , \"SHELLEY_OPCERT=/var/cluster/genesis/node-keys/node\(.value.i).opcert\"

                          , \"RTS_FLAGS=+RTS -N2 -I0 -A16m -qg -qb --disable-delayed-os-memory-return -RTS\"
                        ]
                    }
                }
              )
          )
#          +
#          (
#              .
#            |
#              with_entries(
#                {
#                    key: \"\(.key)-tracer\"
#                  , value: {
#                      container_name: \"\(.value.name)-tracer\"
#                    , pull_policy: \"never\"
#                    , image: \"$tracerImageName:$tracerImageTag\"
#                    , networks: {
#                        \"cardano-tracer-network\": {
#                          ipv4_address: \"172.23.\(.value.i / 254 | floor).\(.value.i % 254 + 1)\"
#                        }
#                    }
#                    , volumes: [
#                        \"NODE-\(.value.name):/var/cardano-node\"
#                      , \"TRACER:/var/cardano-tracer\"
#                    ]
#                    , environment: [
#                        \"HOME=/var/cardano-node\"
#                      , \"TRACER_CONFIG=/var/cardano-tracer/config.json\"
#                    ]
#                  }
#                }
#              )
#          )
          +
          ({
            \"tracer\": {
                container_name: \"tracer\"
              , pull_policy: \"never\"
              , image: \"$tracerImageName:$tracerImageTag\"
              , networks: {
                \"cardano-tracer-network\": {
                  ipv4_address: \"172.23.255.253\"
                }
              }
              , volumes: [
                \"TRACER:/var/cardano-tracer\"
              ]
              , environment: [
                  \"HOME=/var/cardano-tracer\"
                , \"TRACER_CONFIG=/var/cardano-tracer/config.json\"
              ]
            }
          })
        )
        , \"networks\": {
            \"cardano-node-network\": {
                external: false
              , attachable: true
              , driver: \"bridge\"
              , driver_opts: {}
              , enable_ipv6: false
              , ipam: {
                  driver: \"default\"
                , config: [{
                    subnet: \"172.22.0.0/16\"
                  , ip_range: \"172.22.0.0/16\"
                  , gateway: \"172.22.255.254\"
                  , aux_addresses: {}
                }]
              }
            }
          , \"cardano-tracer-network\": {
                external: false
              , attachable: true
              , driver: \"bridge\"
              , driver_opts: {}
              , enable_ipv6: false
              , ipam: {
                  driver: \"default\"
                , config: [{
                    subnet: \"172.23.0.0/16\"
                  , ip_range: \"172.23.0.0/16\"
                  , gateway: \"172.23.255.254\"
                  , aux_addresses: {}
                }]
              }
            }
        }
        , volumes:
          (
              .
            | with_entries (
                {
                    key: \"NODE-\(.value.name)\"
                  , value: {
                        external: false
                      , driver_opts: {
                            type: \"none\"
                          , o: \"bind\"
                          , device: \"./run/\${WB_RUNDIR_TAG:-current}/\(.value.name)\"
                      }
                  }
                }
              )
            +
              {SHARED:
                {
                    external: false
                  , driver_opts: {
                        type: \"none\"
                      , o: \"bind\"
                      , device: \"./run/\${WB_RUNDIR_TAG:-current}\"
                  }
                }
              }
            +
              {TRACER:
                {
                    external: false
                  , driver_opts: {
                        type: \"none\"
                      , o: \"bind\"
                      , device: \"./run/\${WB_RUNDIR_TAG:-current}/tracer\"
                  }
                }
              }
          )
      }" $nodespecs;;

    * ) usage_app;; esac
}
