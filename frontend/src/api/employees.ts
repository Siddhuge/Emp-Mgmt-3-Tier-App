import { api } from "./client";
import type { Employee, EmployeeInput } from "../types";

export async function listEmployees(search?: string): Promise<Employee[]> {
  const { data } = await api.get<Employee[]>("/employees", {
    params: search ? { search } : undefined,
  });
  return data;
}

export async function createEmployee(input: EmployeeInput): Promise<Employee> {
  const { data } = await api.post<Employee>("/employees", input);
  return data;
}

export async function updateEmployee(
  id: number,
  input: Partial<EmployeeInput>,
): Promise<Employee> {
  const { data } = await api.put<Employee>(`/employees/${id}`, input);
  return data;
}

export async function deleteEmployee(id: number): Promise<void> {
  await api.delete(`/employees/${id}`);
}
