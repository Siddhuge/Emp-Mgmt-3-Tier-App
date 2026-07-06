import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import * as api from "../api/departments";
import type { DepartmentInput } from "../types";

export function useDepartments() {
  return useQuery({
    queryKey: ["departments"],
    queryFn: api.listDepartments,
  });
}

export function useCreateDepartment() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (input: DepartmentInput) => api.createDepartment(input),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["departments"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });
}
