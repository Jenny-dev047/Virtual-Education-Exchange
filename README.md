# Virtual Education Exchange Platform

A decentralized platform connecting high school students globally for virtual exchange programs focused on education and cultural understanding.

## Overview

This smart contract facilitates international student connections through virtual exchange programs. Students create profiles, match with peers from different countries, and complete cultural and educational exchanges with blockchain-verified participation.

## Features

- **Student Profiles**: Register with country, interests, and grade level
- **Smart Matching**: Connect students with compatible peers globally
- **Exchange Tracking**: Monitor active and completed exchanges
- **Feedback System**: Rate and review exchange experiences
- **Participation Records**: Permanent record of international exchanges

## Contract Functions

### Public Functions

- `register-student`: Create student profile for exchange program
- `create-match`: Initiate exchange with another student
- `complete-exchange`: Mark exchange as completed
- `submit-feedback`: Rate exchange experience (1-5 scale)

### Read-Only Functions

- `get-student-profile`: Retrieve student profile data
- `get-match`: View exchange match details
- `get-feedback`: Check feedback for specific exchange
- `get-total-students`: Count registered students
- `get-total-matches`: Count total exchanges created

## Exchange Process

1. Students register with profile information
2. Create