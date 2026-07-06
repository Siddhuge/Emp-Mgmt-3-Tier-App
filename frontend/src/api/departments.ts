import { api } from "./client";
import type { Department, DepartmentInput } from "../types";

export async function listDepartments(): Promise<Department[]> {
  const { data } = await api.get<Department[]>("/departments");
  return data;
}

export async function createDepartment(
  input: DepartmentInput,
): Promise<Department> {
  const { data } = await api.post<Department>("/departments", input);
  return data;
}
