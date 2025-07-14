# Test Suite

## Estructura
- `test_unit.py` - Tests unitarios (JWT, validaciones, formatos)
- `test_integration.py` - Tests de integración (endpoints completos)
- `conftest.py` - Fixtures compartidos

## Ejecutar Tests

```bash
# Todos los tests
pytest

# Con coverage (mínimo 90%)
pytest --cov=src

# Tests específicos
pytest tests/test_unit.py
pytest tests/test_integration.py
```

## Coverage
- Mínimo requerido: 90%
- Reporte HTML: `htmlcov/index.html`