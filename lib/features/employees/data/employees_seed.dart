import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_entry.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';

const _development = 'Desarrollo';
const _quality = 'Calidad';
const _coreErp = 'Core ERP Backend';
const _frontend = 'Frontend Arquitectura & UI';
const _qa = 'QA Automation';
const _coreErpManager = 'Lucas Gómez';
const _frontendManager = 'Valeria Ríos';
const _qaManager = 'Sebastián González';

final employeesSeed = [
  Employee(
    employeeId: 'EMP-001',
    firstName: 'Sofía',
    lastName: 'Martínez',
    email: 'sofia.martinez@finnegans-demo.com',
    seniority: Seniority.trainee,
    area: _development,
    team: _coreErp,
    manager: _coreErpManager,
    hireDate: DateTime(2025, 3, 3),
  ),
  Employee(
    employeeId: 'EMP-002',
    firstName: 'Tomás',
    lastName: 'Pereyra',
    email: 'tomas.pereyra@finnegans-demo.com',
    seniority: Seniority.junior2,
    area: _development,
    team: _coreErp,
    manager: _coreErpManager,
    hireDate: DateTime(2024, 8, 12),
  ),
  Employee(
    employeeId: 'EMP-003',
    firstName: 'Lucas',
    lastName: 'Gómez',
    email: 'lucas.gomez@finnegans-demo.com',
    seniority: Seniority.manager,
    area: _development,
    team: _coreErp,
    manager: _coreErpManager,
    hireDate: DateTime(2024, 2, 1),
  ),
  Employee(
    employeeId: 'EMP-004',
    firstName: 'Julieta',
    lastName: 'Romero',
    email: 'julieta.romero@finnegans-demo.com',
    seniority: Seniority.junior1,
    area: _development,
    team: _coreErp,
    manager: _coreErpManager,
    hireDate: DateTime(2024, 3, 4),
    isActive: false,
  ),
  Employee(
    employeeId: 'EMP-005',
    firstName: 'Valeria',
    lastName: 'Ríos',
    email: 'valeria.rios@finnegans-demo.com',
    seniority: Seniority.senior1,
    area: _development,
    team: _frontend,
    manager: _frontendManager,
    hireDate: DateTime(2024, 5, 6),
  ),
  Employee(
    employeeId: 'EMP-006',
    firstName: 'Martín',
    lastName: 'Castro',
    email: 'martin.castro@finnegans-demo.com',
    seniority: Seniority.junior1,
    area: _development,
    team: _frontend,
    manager: _frontendManager,
    hireDate: DateTime(2025, 1, 13),
  ),
  Employee(
    employeeId: 'EMP-007',
    firstName: 'Sebastián',
    lastName: 'González',
    email: 'sebastian.gonzalez@finnegans-demo.com',
    seniority: Seniority.semisenior2,
    area: _quality,
    team: _qa,
    manager: _qaManager,
    hireDate: DateTime(2024, 9, 2),
  ),
  Employee(
    employeeId: 'EMP-008',
    firstName: 'Diego',
    lastName: 'Fernández',
    email: 'diego.fernandez@finnegans-demo.com',
    seniority: Seniority.junior3,
    area: _quality,
    team: _qa,
    manager: _qaManager,
    hireDate: DateTime(2024, 11, 18),
  ),
  Employee(
    employeeId: 'EMP-009',
    firstName: 'Carolina',
    lastName: 'Herrera',
    email: 'carolina.herrera@finnegans-demo.com',
    seniority: Seniority.senior2,
    area: _quality,
    team: _qa,
    manager: _qaManager,
    hireDate: DateTime(2025, 6, 2),
  ),
];

/// EMP-004 left on 2026-06-01: the payroll keeps the row as inactive and the
/// history shows from when it stops counting. The rest of the employees get
/// their initial validity from the repository.
final employeeHistorySeed = [
  EmployeeHistoryEntry(
    employeeId: 'EMP-004',
    seniority: Seniority.junior1,
    area: _development,
    team: _coreErp,
    manager: _coreErpManager,
    isActive: true,
    validFrom: DateTime(2024, 3, 4),
    validTo: DateTime(2026, 6),
  ),
  EmployeeHistoryEntry(
    employeeId: 'EMP-004',
    seniority: Seniority.junior1,
    area: _development,
    team: _coreErp,
    manager: _coreErpManager,
    isActive: false,
    validFrom: DateTime(2026, 6),
  ),
];
