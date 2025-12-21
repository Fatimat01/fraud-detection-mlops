#!/bin/bash

# mkdir -p .github/workflows
# mkdir -p src/{data,features,training,serving}
# mkdir -p tests/{unit,integration}
# mkdir -p docker configs

# # Create empty __init__.py files
# touch src/__init__.py
# touch src/{data,features,training,serving}/__init__.py
# touch tests/__init__.py

# # Create virtual environment
# python -m venv venv
# source venv/bin/activate  # Linux/Mac
# # or: .\venv\Scripts\activate  # Windows

# # Install dependencies
# pip install -e ".[dev]"

# # Install pre-commit hooks
# pre-commit install


# # makefile setup
# make install

# # Run on all files (first time)
# pre-commit run --all-files

mkdir -p infrastructure/terraform/{modules,environments}
mkdir -p infrastructure/terraform/modules/{vpc,eks,ecr,s3,rds}
mkdir -p infrastructure/terraform/environments/{dev,staging,prod}
