# Tests

## Run Tests
```bash
# All tests
pytest

# With coverage
pytest --cov=src

# Specific tests
pytest tests/test_unit.py
pytest tests/test_integration.py
```

## Test Files
- `test_unit.py` - Unit tests
- `test_integration.py` - Integration tests
- `conftest.py` - Shared fixtures