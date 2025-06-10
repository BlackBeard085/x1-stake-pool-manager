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
![Alt text](https://raw.githubusercontent.com/BlackBeard085/Images/refs/heads/main/NoPoolConnected.jpg)

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

Once Connected, the pool details will show upon the dashboard. This image shows validators also shortlisted.

![Alt text](https://raw.githubusercontent.com/BlackBeard085/Images/refs/heads/main/StakePoolManagerMenu.jpg)

## Setting up Stake Pool and Shortlist Parameters
Select Option 6 or edit the config.json to set the parameters of the pool and condtions the validators must meet to be shortlisted.
These can be as lenient or as strict as you like. To exclude a parameter from vetting enter '-'

```bash
   Enter a value for each parameter or '-' to exclude the metric from vetting
   Enter the maximum skip rate a validator can have (10 for 10%):  #higher skip rates will be excluded from the pool
   Enter the maximum commission the validator can charge:          #higher commisions will be excluded from the pool
   Enter the minimum active stake requirement:                     #lower stake will be excluded from the pool
   Enter the maximum active stake requirment:                      #higher stake will be excluded from the pool
   Enter the last full epoch credit requirement (0 - 8000):        #lower credits earned will be excluded
   What is the minimum Total Credits requirement:                  #total credits will enforce minimum uptime requirement
   Please enter the minimum latency requirement:                      #higher latency will be excluded
   Please enter the Validator average credits requirment (0 - 8000):  #lower average credits will be excluded.
   What is the minimum amount of XNT you wish to keep in the reserve? 
   How much would you like to delegate to each validator? 
   ```

## Fund the Stake Pool
You must fund the Stake Pool before adding validators. Fund the pool using option 3. Enter the total amount of funds you wish to be managed by the pool manager.

## Update Pool Validators
Select Option 2 to automatically check all current validators on chain, their performance metrics and vett them against pool requirments to create a shortlist of validators and include qualifying Validators into the pool. examine the following flow chart how this works.


![Alt text](https://raw.githubusercontent.com/BlackBeard085/Images/refs/heads/main/StakepoolManagerFlowchart.jpg)

## Stake to Pool Validators
Once the program has selected the qualifying validators, select option 3 to stake to all validators the amount specified in the configuration setup. All validators will be staked by this amount.

***Function to be added - all validators will be staked by the requested amount and maintaining a minimum balance within the stake pool. If the balance drops below the minimum amount set, the manager will prompt you to change the staking amount to maintain a minimum reserve balance.

## Remove all Validators
option 4 will create a backup of the current validators in the stake pool and attempt to remove all validators within the pool before clearing the poll validator list and shortlist.






