# SecurityCouncil

**SecurityCouncil** is a Solidity smart contract developed to fortify the governance of the Ethereum Name Service (ENS) DAO against potential threats to its treasury and protocol integrity. It implements a Security Council with the authority to cancel malicious proposals and features an expiration mechanism to prevent centralization of power. For more details on the proposal, please refer to [this document](link_to_full_proposal).

## Features

- **Proposal Cancellation**: Allows the Security Council multisig to cancel proposals within a timelock, mitigating the risk of malicious actions.
- **Expiration Mechanism**: Implements an expiration feature where the Security Council's veto power automatically expires after a specified time period (2 years), promoting decentralization.
- **Access Control**: Utilizes OpenZeppelin's AccessControl contract to manage roles and permissions, ensuring only authorized entities can invoke the veto functionality.

## Usage

To utilize the SecurityCouncil contract, follow these steps:

1. **Set security council multisig**: Deploy a 4/8 multisig.
2. **Deploy contract**: Deploy the SecurityCouncil contract to Mainnet.
3. **Grant roles**: Grant the VETO_ROLE to the Security Council multisig address using the grantRole function in the timelock, through an Executable Proposal.
4. **Vetoing malicious proposals**: Once the contract is deployed and roles are granted, the Security Council is set.
5. **Expiration management**: After the specified expiration period (2 years), anyone can revoke the PROPOSER_ROLE from the Security Council, ensuring a time-limited mechanism for governance.

## Running Tests with Mainnet Fork

1. **Setup .env File**: Create a `.env` file in the root directory of your project. Add the following line and replace `YOUR_RPC_URL_MAINNET` with your Mainnet RPC URL:
    ```env
    RPC_URL_MAINNET=YOUR_RPC_URL_MAINNET
    ```

2. **Run Tests**: Ensure you have [Foundry](https://github.com/dapp.tools/foundry) installed. Then, run the following command to execute tests with a Mainnet fork:
    ```bash
    foundry test
    ```

## Security Considerations

Assigning the PROPOSER_ROLE to a multisig within the timelock contract is overly broad for our requirements as it allows the address to add proposals directly to the queue. If the multisig signers are compromised, they could potentially propose and execute malicious changes. Therefore, our approach would be to deploy a new contract similar to the current veto.ensdao.eth contract, which can only do one action: to CANCEL a transaction in the timelock. That would be a trivially simple contract and it would be hard locked to only accept calls from a newly created SAFE multisig.

With that in mind, ensuring the Security Council's multisig operates securely is essential. Availability of Signers and Secure Wallet Practices are crucial considerations for maintaining the integrity of the Security Council's operations.

The Security Council is expected to act only in emergencies and uphold the interests of the ENS DAO. Their responsibilities include understanding the ENS DAO thoroughly, listening to community feedback, taking quick action on behalf of the DAO, and comprehending the repercussions of approved proposals.

The Security Council members will be the same signers for the veto.ensdao.eth, their identities are known, have signed a pledge to uphold the ENS constitution, and reside in countries with a solid legal system.

## License

This contract is available under the MIT license.
