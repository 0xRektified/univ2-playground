# ZKP

## Base

There is 2 entities iimportant in ZKP.

The proover and the verifier.

The proover is able to proove that he know a solution without revealing it.

There is 3 important notion for this:

Completness:
If the statement is true an honest prover must be able to convince the verifier

Soundness:
If the statement is false no dishonest prover can convince an honest verifier

Zero knowledge:
The verifier must learn nothing except that the prover's statement is true

- What is one of the advantages that Zero-Knowledge Proofs provide within the domain of blockchain systems?

Enabling enhanced privacy for transactions or data.

- What is the primary characteristic of a Zero-Knowledge Proof (ZKP)?

It allows a prover to demonstrate knowledge of a secret to a verifier without revealing the secret itself.

- Which of the following is a fundamental property that a Zero-Knowledge Proof protocol must satisfy?

Soundness

- In the context of blockchain technology, what is a key benefit of using Zero-Knowledge Proofs in ZK-Rollups?

Improving scalability by bundling transactions and verifying them with a single proof.

- In a Zero-Knowledge Proof interaction, what are the roles of the two primary parties involved?

A Prover, who aims to prove knowledge, and a Verifier, who checks the proof satisfies the requirements.

- How can Zero-Knowledge Proofs be applied to enhance privacy in an age verification scenario?

By allowing an individual to prove they meet an age requirement without revealing their exact date of birth or other personal details.


## Type of ZK

### Interactive ZK Proof

Back an forth between the proover and verifier.

Repeat challenge / response untill Verifier is convinced, there is multiple round of verification they are really time consuming, need to maintain the state untill multiple round.


### Non-interactive ZK Proof

Only one round of verification, the prover send only one message to the verifier.

## ZK terminology

### Claim /statement

Is an assertion that something is true. in the context of zero-knowledge proofs (ZKPs) it referes to the property being proven without revealing additional information

It is the "claim" the prover is making about the "witness".

"I know x such tht x^2=9"

"i am over the minimum ager" So i can enter the club

### Private and public inputs

- Private inputs are inputs to the system which are only known to the prover and not the verifier (the witness)

X in the example of the private input
age in the example of the private input

- Public inputs known to both the prover and the verifier

Minimum age is the public input

- Constaint , mathematical condition which must be satisfied in order for the claim to be valid
Constraints define the rules the inputs must follow.

assert that `x2=9` is the constraint

OR

`x*x = Z` is the constraint
`Z - 9 = 0` is the constraint

In the above example my_age >= min_age is the constraint

### Circuit

A system of constraints makes up the circuit

A series of mathematical relations and operations

The circuit defines how the constraints work together

we could have only one constraint in a circuit or multiples constraint that will make the circuit

### Witness

The set of private values that allow a prover to demonstrate that their claim or statement is valid/true

Include the private inputs but also can include intermediate calculations

The witness must satisfy the constraints of the circuit

![image](./zkpimg/1-terms.png)