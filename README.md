**Disclaimer - Please read all relevant documents and carry out any necessary due diligence before using X1 Console. By using X1 Console, you acknowledge that you have read the documentation and understand the risks associated with cryptocurrency and related products. You agree that the creator of X1 Console is not liable for any damages or losses that may arise from your use of this product. Use at your own risk.**

# X1 Stake Pool Manager - Jack The Ripper
Welcome to X1's stake Pool Manager - Jack The Ripper, an interactive, automated tool designed for managing and vetting validators within an X1 stake pool. Created by BlackBeard, it simplifies the process of setting up, connecting, and maintaining stake pools by providing features such as validator vetting based on customizable parameters, staking, fund management, and validator removal. It ensures only validators with the best performance are delgated to.

![Alt text](https://raw.githubusercontent.com/BlackBeard085/Images/refs/heads/main/JackTheRipper.jpg)

## Recommended Sequence of manual operation
If you run the manager manually it is recommended to run the operations in the following order as stakes will take 1 epoch to deactivate after removing validators from the pool and the pool reserve balance to update accordingly.



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

On the opening dash, select Option 7, Connect Pool, to set up your SPL Stake Pool with the stake pool manager. You will asked to input the keypair paths to the SPL Stake Pool generated accounts and also the path to the spl-stake-pool binary or command prompt. 

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
Option 4 will create a backup of the current validators in the stake pool and attempt to remove all validators within the pool before clearing the poll validator list and shortlist.

## Withdraw Unstaked Reserve Funds
Option 5, withdraw any amount that is not staked to Validators.

## Update Pool data
option 6 or manual command
```bash
   ./update.sh
   ```
to update pool data. Once validators are added or removed from the pool, it may need updating to show the more upto date number of validators or reserve balance. Usually required on the following Epoch after removing validators from the pool.




