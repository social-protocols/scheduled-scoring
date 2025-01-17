# List available recipes in the order in which they appear in this file
_default:
    @just --list --unsorted

instantiate:
    julia --project -e 'using Pkg; Pkg.instantiate()'

format:
    cd app && npx prettier --write --ignore-path public/google-charts-loader.js .
    cd globalbrain-node && npx prettier --write . 
    julia -e 'using Pkg; Pkg.add("JuliaFormatter")'
    julia --eval "using JuliaFormatter; format(joinpath(pwd(), \"src\"))"
    julia --eval "using JuliaFormatter; format(joinpath(pwd(), \"simulations\"))"
    julia --eval "using JuliaFormatter; format(joinpath(pwd(), \"simulations/scenarios\"))"

db query="":
    litecli $DATABASE_PATH -e "{{query}}"

reset-db:
    rm -f $DATABASE_PATH
    julia --project --eval "using GlobalBrain; init_score_db(ARGS[1])" $DATABASE_PATH
    rm ~/social-protocols-data/score-events.jsonl

sim name="":
    time julia --project=simulations simulations/run.jl {{name}}

sim-db query="":
    litecli $SIM_DATABASE_PATH -e "{{query}}"

test-db query="":
    litecli $SOCIAL_PROTOCOLS_DATADIR/test.db -e "{{query}}"

visualize:
    cd app && npm install && npm run dev

typecheck: 
    cd app && npx tsc

ci-test:
    earthly +ci-test

build-shared-library:
    rm -rf globalbrain-node/julia/build
    cd globalbrain-node/julia && time julia -t auto --startup-file=no --project -e 'using Pkg; Pkg.instantiate(); include("build.jl")'

docker-build:
  earthly +docker-build

docker-run:
  docker run --user $(id -u):$(id -g) -p 8000:8000 -e DATABASE_PATH=/tmp/globalbrain.db global-brain


############ TESTS ##############

test:
    julia --project --eval "using Pkg; Pkg.test()"
    ./test.sh
