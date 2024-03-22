aptos init \
  --rest-url 'https://fullnode.random.aptoslabs.com/v1' \
  --faucet-url 'https://faucet.random.aptoslabs.com' \
  --network custom
  
aptos account fund-with-faucet \
  --faucet-url 'https://faucet.random.aptoslabs.com' \
  --account 0xbfb4153132b66aa462b33d2a74c52a1b7fe711758af32f5b66dbff725a10f630 \
  --amount 200000000000000
  
aptos move publish \
  --bytecode-version 6 \
  --check-test-code \
  --node-api-key 'aptoslabs_ArSW7gjSpNM_9hJBSKCaM7AL5EFSgKjL9HXy8CDEZqVDE'
  
aptos move run \
  --function-id default::house::init \
  --args u64:20000000000 u64:10000000 u64:2000000000 u64:50 u64:100
  
aptos move run \
  --function-id default::dice::approve_game
  
aptos move run \
  --function-id default::roulette::approve_game
  
aptos move run \
  --function-id default::mines::init
  
aptos move run \
  --function-id default::mines::approve_game
  
aptos move run \
  --function-id default::blackjack::approve_game
  
aptos move run \
  --function-id default::blackjack::init
  
  
alias aptos='~/aptos-core/target/release/aptos'
