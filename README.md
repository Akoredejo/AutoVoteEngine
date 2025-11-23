⚙️ AutoVoteEngine
=================

A decentralized governance system implemented in Clarity, designed to facilitate weighted voting, customizable delegation strategies, and autonomous execution of voting decisions.

* * * * *

📜 Contract Overview
--------------------

The `AutoVoteEngine` contract provides a comprehensive framework for a decentralized autonomous organization (DAO) or a similar governance structure. It supports the lifecycle of **proposals**, from creation to execution, incorporating **weighted voting**, configurable **quorum** requirements, and a unique **strategy engine** that allows users to define rules for automated voting and delegation.

### Key Features

-   **Weighted Voting:** Voting power is assigned to principals (users) via the `set-voting-power` function, allowing for token-weighted or stake-based governance models.

-   **Proposal Lifecycle:** Proposals are time-locked, starting at creation block and ending after a fixed duration (`proposal-duration`). They can only be executed if the voting period has ended and the required **quorum** is met.

-   **Delegation:** Users can delegate a specific amount of their voting power to another principal using `delegate-voting-power`. This delegated power is temporarily subtracted from the delegator and added to the delegate.

-   **Autonomous Strategies:** Users can create custom **voting strategies** defining an **auto-vote** preference and a **minimum quorum threshold**. This allows for "lazy governance," where votes are cast automatically via the `execute-autonomous-vote` function once the proposal has achieved a sufficient quorum.

-   **Role-Based Access Control (RBAC):** The `set-voting-power` function is restricted to the `contract-owner`, ensuring centralized control over the initial distribution or adjustment of voting power.

* * * * *

🛠️ Data Structures and Maps
----------------------------

The contract utilizes several data variables and maps to store the state of the voting system:

### Variables

| Variable Name | Type | Description |
| --- | --- | --- |
| `proposal-count` | `uint` | A counter for the total number of proposals created. |
| `total-voting-power` | `uint` | The sum of all assigned voting power across all users. Used for quorum calculation. |

### Maps

| Map Name | Key Structure | Value Structure | Description |
| --- | --- | --- | --- |
| `proposals` | `uint` (Proposal ID) | `{proposer: principal, title: (string-ascii 100), description: (string-ascii 500), votes-for: uint, votes-against: uint, start-block: uint, end-block: uint, executed: bool, quorum-required: uint, status: (string-ascii 20)}` | Stores the details and current state of each proposal. |
| `votes` | `{proposal-id: uint, voter: principal}` | `{vote-weight: uint, vote-choice: bool, voted-at: uint}` | Records every individual vote cast, including the weight used. |
| `voting-power` | `principal` (User) | `uint` | Stores the base voting power assigned to each principal. |
| `voting-strategies` | `{owner: principal, strategy-id: uint}` | `{name: (string-ascii 50), auto-vote: bool, vote-preference: bool, min-quorum-threshold: uint, delegate-to: (optional principal), active: bool}` | Defines the custom, potentially autonomous, voting rules set by a user. |
| `user-strategy-count` | `principal` (Owner) | `uint` | Tracks the number of strategies created by each user to assign unique strategy IDs. |
| `delegations` | `{delegator: principal, delegate: principal}` | `{voting-power-delegated: uint, active: bool, created-at: uint}` | Records active and past power delegation arrangements between users. |

* * * * *

🤫 Private Functions
--------------------

These functions are internal helpers used exclusively by the public functions to encapsulate logic and maintain state consistency. They cannot be called directly by users.

| Function Name | Parameters | Returns | Description |
| --- | --- | --- | --- |
| `is-quorum-met` | `(proposal-id uint)` | `bool` | Calculates if the total votes cast for a proposal meet the required quorum threshold. |
| `is-proposal-active` | `(proposal-id uint)` | `bool` | Checks if the current `block-height` is within the proposal's `start-block` and `end-block`, and if the proposal is not yet executed. |
| `get-effective-voting-power` | `(voter principal)` | `uint` | Retrieves the base voting power for a principal from the `voting-power` map. (Note: In the current implementation, it returns base power, assuming delegation effects are applied directly to the `voting-power` map). |
| `update-proposal-status` | `(proposal-id uint)` | `(response bool)` | Updates the proposal's status to "executed," "passed," or "failed" based on `block-height` and quorum status. |

* * * * *

⚙️ Public Functions (Entrypoints)
---------------------------------

These are the functions that users can call to interact with the contract.

### 1\. `set-voting-power`

Code snippet

```
(define-public (set-voting-power (user principal) (power uint))

```

-   **Description:** Initializes or updates the voting power for a specific user. This function is restricted to the `contract-owner`.

-   **Access:** **Contract Owner Only**.

### 2\. `create-proposal`

Code snippet

```
(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)))

```

-   **Description:** Creates a new proposal. The proposal's `quorum-required` is calculated based on `total-voting-power` and `min-quorum-percentage` (20%).

### 3\. `vote`

Code snippet

```
(define-public (vote (proposal-id uint) (vote-for bool)))

```

-   **Description:** Allows a user to cast a manual, direct vote on an active proposal using their effective voting power.

-   **Pre-conditions:** Proposal must be active, user must not have already voted, and must have >u0 power.

### 4\. `create-voting-strategy`

Code snippet

```
(define-public (create-voting-strategy (name (string-ascii 50)) (auto-vote bool) (vote-preference bool) (min-quorum uint) (delegate (optional principal)))

```

-   **Description:** Creates a personalized voting strategy for the sender, configurable for **autonomous voting** (`auto-vote: true`).

### 5\. `delegate-voting-power`

Code snippet

```
(define-public (delegate-voting-power (delegate principal) (power uint)))

```

-   **Description:** Delegates a specific amount of the sender's voting power to another principal.

### 6\. `revoke-delegation`

Code snippet

```
(define-public (revoke-delegation (delegate principal)))

```

-   **Description:** Reclaims previously delegated voting power from a specific delegate.

### 7\. `execute-proposal`

Code snippet

```
(define-public (execute-proposal (proposal-id uint)))

```

-   **Description:** Finalizes a proposal after its voting period has ended, provided the required quorum is met.

### 8\. `execute-autonomous-vote` 🚀

Code snippet

```
(define-public (execute-autonomous-vote (proposal-id uint) (strategy-owner principal) (strategy-id uint)))

```

-   **Description:** Executes a pre-defined, auto-enabled voting strategy on behalf of the `strategy-owner`, provided the proposal has reached the strategy's minimum quorum threshold.

* * * * *

👁️ Read-Only Functions
-----------------------

These functions allow querying the contract state without initiating a transaction.

| Function Name | Parameters | Returns | Description |
| --- | --- | --- | --- |
| `get-proposal` | `(proposal-id uint)` | `(optional { ...proposal details... })` | Retrieves a proposal's full details by ID. |
| `get-vote` | `(proposal-id uint) (voter principal)` | `(optional { ...vote details... })` | Retrieves the vote record for a specific user on a proposal. |
| `get-user-voting-power` | `(user principal)` | `uint` | Returns the user's base voting power. |
| `get-strategy` | `(owner principal) (strategy-id uint)` | `(optional { ...strategy details... })` | Retrieves a user's specific voting strategy. |

* * * * *

🔒 Error Codes
--------------

The contract uses defined constants for all error conditions:

| Error Code | Constant | Description |
| --- | --- | --- |
| `u100` | `err-owner-only` | Function restricted to the contract owner. |
| `u101` | `err-not-found` | Proposal or delegation record not found. |
| `u102` | `err-unauthorized` | Action is not allowed (e.g., executing a non-auto-vote strategy). |
| `u103` | `err-already-voted` | User has already voted on the proposal. |
| `u104` | `err-proposal-closed` | Proposal voting period has ended or it's already executed. |
| `u105` | `err-proposal-active` | Proposal is still in the active voting phase. |
| `u106` | `err-insufficient-votes` | User has insufficient voting power for the action (vote or delegation). |
| `u107` | `err-invalid-strategy` | The specified voting strategy is invalid or inactive. |
| `u108` | `err-quorum-not-met` | The minimum required quorum has not been reached. |

* * * * *

⏳ Configuration Constants
-------------------------

The system's behavior is controlled by these governance constants:

| Constant | Value | Description |
| --- | --- | --- |
| `proposal-duration` | `u1440` | The number of blocks a proposal remains open for voting (approximately 10 days). |
| `min-quorum-percentage` | `u20` | The minimum percentage of `total-voting-power` required to cast a vote for a proposal to be eligible for execution (20%). |

* * * * *

🤝 Contribution
---------------

Contributions are welcome! If you find a bug, have a suggestion for an enhancement, or want to submit a new feature, please follow these guidelines:

1.  **Fork** the repository.

2.  Create a new feature branch (`git checkout -b feature/AmazingFeature`).

3.  Commit your changes (`git commit -m 'feat: Add AmazingFeature'`).

4.  Push to the branch (`git push origin feature/AmazingFeature`).

5.  Open a **Pull Request**.

All submitted code must adhere to the Clarity Smart Contract language best practices, including efficient gas usage and comprehensive error handling. New features should be accompanied by detailed test cases.

* * * * *

⚖️ License
----------

The `AutoVoteEngine` is released under the **MIT License**.

```
MIT License

Copyright (c) 2025 AutoVoteEngine Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```
