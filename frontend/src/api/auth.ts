import { api } from "./client";
import type { User } from "../types";

export async function login(username: string, password: string): Promise<string> {
  const { data } = await api.post<{ access_token: string }>("/login", {
    username,
    password,
  });
  return data.access_token;
}

export async function logout(): Promise<void> {
  await api.post("/logout");
}

export async function getMe(): Promise<User> {
  const { data } = await api.get<User>("/me");
  return data;
}
