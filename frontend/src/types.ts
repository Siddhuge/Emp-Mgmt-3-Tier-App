export type Role = "admin" | "manager" | "employee";

export interface User {
  id: number;
  username: string;
  role: Role;
}

export interface Department {
  id: number;
  name: string;
  manager: string | null;
}

export interface Employee {
  id: number;
  first_name: string;
  last_name: string;
  email: string;
  designation: string | null;
  salary: number | null;
  is_active: boolean;
  department_id: number | null;
  department: Department | null;
  created_at: string;
}

export interface EmployeeInput {
  first_name: string;
  last_name: string;
  email: string;
  designation?: string | null;
  salary?: number | null;
  is_active: boolean;
  department_id?: number | null;
}

export interface DepartmentInput {
  name: string;
  manager?: string | null;
}

export interface DashboardStats {
  total_employees: number;
  departments: number;
  projects: number;
  active_employees: number;
}
