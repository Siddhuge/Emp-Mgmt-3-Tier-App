import { api } from "./client";
import type { DashboardStats } from "../types";

export async function getDashboard(): Promise<DashboardStats> {
  const { data } = await api.get<DashboardStats>("/dashboard");
  return data;
}
