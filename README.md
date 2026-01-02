"# dex-amm" 
# Dex‑AMM

A simple **Decentralized Exchange (DEX)** built using an **Automated Market Maker (AMM)** model — similar in principles to Uniswap.  
This project demonstrates how liquidity pools, token swaps, and price discovery work on Ethereum‑compatible blockchains using smart contracts.

## 🧠 Overview

This project implements a basic AMM DEX using:

- Solidity smart contracts for pool and swap logic
- Hardhat for development, testing, and deployment
- JavaScript/TypeScript scripts for interaction
- Tests to ensure correct behavior

AMM DEXs facilitate trades **without an order book**. Instead, trades happen against a liquidity pool using a pricing formula like a constant product `(x × y = k)`.:contentReference[oaicite:0]{index=0}

## 🛠️ Project Structure

├── contracts/ # Solidity smart contracts
├── scripts/ # Deployment & utility scripts
├── tests/ # Test suite
├── cache/
├── artifacts/
├── hardhat.config.js # Hardhat configuration
├── package.json
└── README.md

## 🚀 Features

- Deployable AMM smart contracts
- Liquidity pool creation
- Token swapping
- Price calculation via AMM formula
- Unit tests to validate core logic

## 🧩 Requirements

Install prerequisites:

```bash
npm install
📦 Local Development
Compile Contracts
npx hardhat compile

Run Local Node
npx hardhat node

Deploy
npx hardhat run scripts/deploy.js --network localhost
Run Tests
npx hardhat test