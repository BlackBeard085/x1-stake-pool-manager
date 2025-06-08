# X1 Stake Pool Manager

## Requirements
You will need to create a stake pool using the SPL Stake Pool program and have access to the generated keys for the stake pool.

## Starting the Stake Pool Manager
clone the Stake Pool manager and open the directory

```bash
   git clone https://github.com/BlackBeard085/x1-stake-pool-manager.git
   cd x1-stake-pool-manager
   ```
Start the Pool Manager
```bash
   ./x1poolmanager.sh
   ```

Opening Dash
## (pic placeholder)

A notification on dash will prompt user to connect a pool to the manager.

## Connecting a SPL Stake Pool

On the opening dash, select Option 7, Connect Pool, to set up your SPL Stake Pool with the stake pool manager. you will asked to input the keypair paths to the SOL Stake Pool generated accounts and also the path to the spl-stake-pool binary or command prompt. 

```bash
   Please enter X1 Stake Pool keypair:
   Please enter Stake Pool Reserve keypair path:
   Please enter Mint keypair path:
   Please enter Funding authority keypair path:
   Please enter Deposit authority keypair path:
   Enter your preferred spl-stake-pool command:
   ```

Once Connected, the pool details will show upon the dashboard.
## (pic placeholder)

## Setting up Shortlist Parameters
Select Option 6 to set the parameters the validators will be vetted againat to be shortlisted.
These can be as lenient or as strict as you like.
