aptos init \
  --rest-url 'https://fullnode.random.aptoslabs.com/v1' \
  --faucet-url 'https://faucet.random.aptoslabs.com' \
  --network custom
  
aptos account fund-with-faucet \
  --faucet-url 'https://faucet.random.aptoslabs.com' \
  --account b2104bc99e57db595ad246a46ff3d57adce17fb33058703ae770c302d0a88b63 \
  --amount 20000000000
  
aptos move publish \
  --bytecode-version 6 \
  --check-test-code \
  --node-api-key 'aptoslabs_ArSW7gjSpNM_9hJBSKCaM7AL5EFSgKjL9HXy8CDEZqVDE'
  
aptos move run \
  --function-id default::house::init \
  --args u64:20000000000 u64:10000000 u64:2000000000 u64:50 u64:200
  
alias aptos='~/aptos-core/target/release/aptos'
