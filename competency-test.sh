set -e

# 0. CLEANUP (Optional)
echo "Stopping any running bitcoind (if any)..."
bitcoin-cli -regtest stop 2>/dev/null || true
sleep 3

# Optional: Remove old regtest data if desired:
# rm -rf ~/.bitcoin/regtest

# 1. START BITCOIND IN REGTEST MODE WITH LEGACY WALLET SUPPORT AND FALLBACK FEE
echo "Starting bitcoind in regtest mode with -deprecatedrpc=create_bdb and -fallbackfee=0.0002..."
bitcoind -regtest -deprecatedrpc=create_bdb -fallbackfee=0.0002 -daemon
sleep 5

# 2. CREATE STANDARD WALLETS FOR SIGNING (wallet1 and wallet2)
echo "Creating wallet1 and wallet2..."
bitcoin-cli -regtest createwallet "wallet1" >/dev/null
bitcoin-cli -regtest createwallet "wallet2" >/dev/null

# 3. GET NEW ADDRESSES & DERIVE PUBKEYS FROM WALLET1 and WALLET2
echo "Generating new addresses and retrieving public keys..."
W1_ADDR=$(bitcoin-cli -regtest -rpcwallet="wallet1" getnewaddress)
W2_ADDR=$(bitcoin-cli -regtest -rpcwallet="wallet2" getnewaddress)
echo "wallet1 address: $W1_ADDR"
echo "wallet2 address: $W2_ADDR"

W1_INFO=$(bitcoin-cli -regtest -rpcwallet="wallet1" getaddressinfo "$W1_ADDR")
W2_INFO=$(bitcoin-cli -regtest -rpcwallet="wallet2" getaddressinfo "$W2_ADDR")
W1_PUB=$(echo "$W1_INFO" | jq -r '.pubkey')
W2_PUB=$(echo "$W2_INFO" | jq -r '.pubkey')
echo "wallet1 pubkey: $W1_PUB"
echo "wallet2 pubkey: $W2_PUB"

# 4. CREATE A WATCH-ONLY MULTISIG WALLET (1-of-2)
echo "Creating multisig wallet (msigwallet) in watch-only mode..."
# Create a legacy wallet by explicitly disabling descriptors (last parameter set to false)
bitcoin-cli -regtest createwallet "msigwallet" false false "" false false >/dev/null

# Create a 1-of-2 multisig address (p2sh-segwit)
MSIG_INFO=$(bitcoin-cli -regtest -rpcwallet="msigwallet" addmultisigaddress 1 "[\"$W1_PUB\",\"$W2_PUB\"]" "" "p2sh-segwit")
MSIG_ADDRESS=$(echo "$MSIG_INFO" | jq -r '.address')
MSIG_REDEEMSCRIPT=$(echo "$MSIG_INFO" | jq -r '.redeemScript')
echo "Multisig address (1-of-2, p2sh-segwit): $MSIG_ADDRESS"
echo "Redeem script: $MSIG_REDEEMSCRIPT"

# 5. FUNDING SETUP: MINE BLOCKS TO FUND wallet1
echo "Mining 101 blocks to wallet1's address to obtain spendable coins..."
bitcoin-cli -regtest generatetoaddress 101 "$W1_ADDR" >/dev/null
BALANCE1=$(bitcoin-cli -regtest -rpcwallet="wallet1" getbalance)
echo "wallet1 balance after mining: $BALANCE1 BTC"

# 6. SEND TRANSACTIONS TO MULTISIG ADDRESS (simulate different cases)

# --- CASE A: Sweep Transaction (1 input, 1 output) ---
echo "=== CASE A: Sweep Transaction (1 input, 1 output) ==="
TXID_A=$(bitcoin-cli -regtest -rpcwallet="wallet1" sendtoaddress "$MSIG_ADDRESS" 0.005)
echo "Sweep TXID: $TXID_A"
bitcoin-cli -regtest generatetoaddress 1 "$W1_ADDR" >/dev/null


# === CASE A: Sweep Transaction (1 input, 1 output) ===
# ... existing Case A code ...

# === CASE A.1: Send 0.005 BTC from wallet1 to wallet2 ===
echo "=== CASE A.1: Send 0.005 BTC from wallet1 to wallet2 ==="
TXID1=$(bitcoin-cli -regtest -rpcwallet=wallet1 sendtoaddress "$W2_ADDR" 0.005)
echo "TXID1: $TXID1"
bitcoin-cli -regtest generatetoaddress 1 "$W1_ADDR"

# === CASE A.2: Send 0.003 BTC from wallet2 to multisig address ===
echo "=== CASE A.2: Send 0.003 BTC from wallet2 to multisig address ==="
TXID2=$(bitcoin-cli -regtest -rpcwallet=wallet2 sendtoaddress "$MSIG_ADDRESS" 0.003)
echo "TXID2: $TXID2"
bitcoin-cli -regtest generatetoaddress 1 "$W1_ADDR"

# === CASE A.3: Send 0.001 BTC from wallet1 to multisig address ===
echo "=== CASE A.3: Send 0.001 BTC from wallet1 to multisig address ==="
TXID3=$(bitcoin-cli -regtest -rpcwallet=wallet1 sendtoaddress "$MSIG_ADDRESS" 0.001)
echo "TXID3: $TXID3"
bitcoin-cli -regtest generatetoaddress 1 "$W1_ADDR"

# View transaction history for wallet1
bitcoin-cli -regtest -rpcwallet=wallet1 listtransactions

# View transaction history for wallet2
bitcoin-cli -regtest -rpcwallet=wallet2 listtransactions

# View transaction history for multisig wallet
bitcoin-cli -regtest -rpcwallet=msigwallet listtransactions


# 8. DISPLAY FULL WALLET TRANSACTION HISTORY (for health analysis)
echo "=== Full Transaction History for msigwallet ==="
bitcoin-cli -regtest -rpcwallet="msigwallet" listtransactions "*" | jq

echo "=== Full Transaction History for wallet1 ==="
bitcoin-cli -regtest -rpcwallet="wallet1" listtransactions "*" | jq

echo "Script complete. Review the printed data to compute your Privacy (p_score) and Fee (f_score) metrics as per your formulas."