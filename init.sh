aptos init \
  --rest-url 'https://fullnode.random.aptoslabs.com/v1' \
  --faucet-url 'https://faucet.random.aptoslabs.com' \
  --network custom
  
aptos account fund-with-faucet \
  --faucet-url 'https://faucet.random.aptoslabs.com' \
  --account a3883496c894715e7d4efc28a32b123390bbe63137c5fa460529e79c1d7d8e68
  
aptos move publish \
  --bytecode-version 6 \
  --check-test-code \
  --node-api-key 'aptoslabs_ArSW7gjSpNM_9hJBSKCaM7AL5EFSgKjL9HXy8CDEZqVDE'
  
