# SkillShareChain: A Decentralized Peer-to-Peer Skill Exchange

Our vision is a decentralized global classroom on **Aptos**. We empower anyone to teach and learn securely through a trustless on-chain protocol, replacing platform fees with transparent rules for a fairer knowledge economy for all.

**SkillShareChain** is a decentralized application (**dApp**) built on the Aptos blockchain that facilitates a trustless marketplace for peer-to-peer skill sharing. The platform connects learners with expert teachers, using a secure, on-chain escrow and communication protocol to ensure fair and transparent interactions without requiring a central intermediary.

---

## Key Features

- **Decentralized Identity**: Users control their own data and profiles via their Aptos wallet.
- **Trustless Escrow**: A 1 APT lesson fee is held securely in an on-chain escrow, only released upon mutual agreement.
- **Secure Contact Exchange**: Private contact information is only revealed after a financial commitment (payment deposit) is made.
- **On-Chain Accountability**: A 24-hour response window and learner-controlled reporting ensure teachers remain responsive.
- **Low Fees**: Operates with minimal transaction fees, removing costly platform commissions.
- **Transparent & Auditable**: All interactions and transactions are public and verifiable on the Aptos blockchain.

---

## The User Flow

### The Happy Path (Successful Lesson)

This flow outlines a successful interaction from start to finish.

1. **Registration**: Alice (Learner) and Bob (Teacher) each connect their wallet and create a profile on SkillShareChain. Bob adds "React Development" to his list of skills.
2. **Discovery & Request**: Alice finds Bob and sends him a request to learn "React Development".
3. **Acceptance**: Bob sees the request in his dashboard and accepts it.
4. **Payment Deposit**: The lesson now appears in Alice's "Lessons" tab. She clicks "Pay 1 APT", which deposits the funds into the smart contract's escrow.
5. **Payment Acknowledgment**: Bob is notified of the payment. He acknowledges it, which triggers the secure exchange of their private contact information.
6. **Communication & Lesson**: Alice and Bob connect off-chain (e.g., via Discord). After they connect, Alice clicks "Mark as Teacher Contacted Me" on the platform.
7. **Completion Request**: Once the lesson is over, Bob clicks "Request Payment Release".
8. **Confirmation & Payment Release**: Alice confirms the lesson was completed. The smart contract automatically releases the 1 APT from escrow to Bob's wallet.

### The Refund Path (Unresponsive Teacher)

This flow protects the learner if a teacher is unresponsive.

1. Steps 1–5 proceed as normal.
2. **Waiting Period**: Bob fails to contact Alice to start the lesson.
3. **Deadline Exceeded**: After 24 hours, a "Report Non-Response" button appears for Alice.
4. **Report & Refund**: Alice clicks the button to report Bob and then clicks "Claim Refund" to instantly retrieve her 1 APT. The lesson is marked as "Refunded".

---

## Technology Stack

- **Blockchain**: Aptos
- **Smart Contracts**: Move Language
- **Frontend**: React, Vite, Tailwind CSS
- **Wallet Integration**: `@aptos-labs/wallet-adapter-react`

---

## Getting Started

Follow these steps to set up and run the project locally.

### Prerequisites

- Node.js (v18 or higher)
- Yarn or npm
- Aptos CLI
- Petra Wallet browser extension

---

### Setup & Run

#### Clone the Repository

```bash
git clone https://github.com/Shubham-Khetan-2005/SkillShareChain.git
cd SkillShareChain
```

#### Deploy Script

```bash
./deploy.sh
```

#### Setup the Frontend

```bash
# Navigate to the frontend directory
cd ../dapp

# Create a .env file from the example
cp .env.example .env

# Edit .env and add your deployed contract address
# VITE_MODULE_ADDR=0x...

# Install dependencies
npm install

# Run the development server
npm run dev
```
---

# Smart Contract API

## Platform Setup Functions

- `init_platform_config(admin: &signer)`:  
  Initializes the global configuration for the platform, including fixed lesson prices and response windows.

- `init_global_requests(admin: &signer)`:  
  Creates the global storage for all lesson requests and their associated events.

- `init_registration_events(admin: &signer)`:  
  Initializes the event handle for tracking new user registrations.

- `init_contract_coin_store(admin: &signer)`:  
  Registers the contract account to hold APT and enables escrow functionality.

---

## User Management Functions

- `register_user_with_contact(user: &signer, name: vector<u8>, contact_info: vector<u8>)`:  
  Registers a new user with their contact information (kept private until a paid lesson is confirmed).

- `add_skill(user: &signer, skill: vector<u8>)`:  
  Adds a teachable skill to a registered user's profile.

---

## Lesson Lifecycle Functions

- `request_teach(learner: &signer, teacher: address, skill: vector<u8>)`:  
  Allows a learner to request a lesson from a registered teacher.

- `accept_request(teacher: &signer, request_id: u64)`:  
  Allows the teacher to accept a pending lesson request.

- `reject_request(teacher: &signer, request_id: u64)`:  
  Allows the teacher to reject a pending lesson request.

---

## Payment & Escrow Functions

- `deposit_payment(learner: &signer, request_id: u64)`:  
  Learner deposits 1 APT into the escrow for an accepted lesson.

- `acknowledge_payment(teacher: &signer, request_id: u64)`:  
  Teacher acknowledges the learner's payment and triggers contact information exchange.

- `teacher_request_release(teacher: &signer, request_id: u64)`:  
  Teacher requests the release of escrowed funds after the lesson is complete.

- `learner_confirm_completion(learner: &signer, admin: &signer, request_id: u64)`:  
  Learner confirms lesson completion, which releases the escrowed funds to the teacher (requires admin's co-signature).

---

## Dispute & Refund Functions

- `learner_mark_communication_started(learner: &signer, request_id: u64)`:  
  Learner confirms that the teacher has initiated communication.

- `learner_report_non_response(learner: &signer, request_id: u64)`:  
  Learner reports if the teacher hasn't responded within 24 hours.

- `claim_refund(learner: &signer, admin: &signer, request_id: u64)`:  
  After reporting non-response, the learner can claim a refund (requires platform admin's signature).

---

## View Functions (Read-Only)

- `user_exists(addr: address): bool`:  
  Returns `true` if a user profile exists at the given address.

- `get_contact_info(request_id: u64, requester: address): vector<u8>`:  
  Retrieves the contact info of the other party in a lesson request (only if payment has been acknowledged). 

