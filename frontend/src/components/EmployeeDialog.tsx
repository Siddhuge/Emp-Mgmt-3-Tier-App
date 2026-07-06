import { useEffect, useState } from "react";
import {
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControlLabel,
  MenuItem,
  Stack,
  Switch,
  TextField,
} from "@mui/material";
import type { Department, Employee, EmployeeInput } from "../types";

interface EmployeeDialogProps {
  open: boolean;
  employee: Employee | null;
  departments: Department[];
  onClose: () => void;
  onSubmit: (input: EmployeeInput) => void;
  submitting?: boolean;
  error?: string | null;
}

const emptyForm: EmployeeInput = {
  first_name: "",
  last_name: "",
  email: "",
  designation: "",
  salary: null,
  is_active: true,
  department_id: null,
};

export default function EmployeeDialog({
  open,
  employee,
  departments,
  onClose,
  onSubmit,
  submitting,
  error,
}: EmployeeDialogProps) {
  const [form, setForm] = useState<EmployeeInput>(emptyForm);

  useEffect(() => {
    if (employee) {
      setForm({
        first_name: employee.first_name,
        last_name: employee.last_name,
        email: employee.email,
        designation: employee.designation ?? "",
        salary: employee.salary,
        is_active: employee.is_active,
        department_id: employee.department_id,
      });
    } else {
      setForm(emptyForm);
    }
  }, [employee, open]);

  const update = <K extends keyof EmployeeInput>(key: K, value: EmployeeInput[K]) =>
    setForm((prev) => ({ ...prev, [key]: value }));

  const handleSubmit = () => {
    onSubmit({
      ...form,
      designation: form.designation || null,
      department_id: form.department_id || null,
    });
  };

  const valid = form.first_name && form.last_name && form.email;

  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>{employee ? "Edit Employee" : "Add Employee"}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          <Stack direction={{ xs: "column", sm: "row" }} spacing={2}>
            <TextField
              label="First Name"
              value={form.first_name}
              onChange={(e) => update("first_name", e.target.value)}
              fullWidth
              required
            />
            <TextField
              label="Last Name"
              value={form.last_name}
              onChange={(e) => update("last_name", e.target.value)}
              fullWidth
              required
            />
          </Stack>
          <TextField
            label="Email"
            type="email"
            value={form.email}
            onChange={(e) => update("email", e.target.value)}
            fullWidth
            required
          />
          <TextField
            label="Designation"
            value={form.designation ?? ""}
            onChange={(e) => update("designation", e.target.value)}
            fullWidth
          />
          <Stack direction={{ xs: "column", sm: "row" }} spacing={2}>
            <TextField
              label="Salary"
              type="number"
              value={form.salary ?? ""}
              onChange={(e) =>
                update("salary", e.target.value ? Number(e.target.value) : null)
              }
              fullWidth
            />
            <TextField
              label="Department"
              select
              value={form.department_id ?? ""}
              onChange={(e) =>
                update(
                  "department_id",
                  e.target.value ? Number(e.target.value) : null,
                )
              }
              fullWidth
            >
              <MenuItem value="">
                <em>None</em>
              </MenuItem>
              {departments.map((d) => (
                <MenuItem key={d.id} value={d.id}>
                  {d.name}
                </MenuItem>
              ))}
            </TextField>
          </Stack>
          <FormControlLabel
            control={
              <Switch
                checked={form.is_active}
                onChange={(e) => update("is_active", e.target.checked)}
              />
            }
            label="Active"
          />
          {error && (
            <TextField
              value={error}
              error
              fullWidth
              disabled
              variant="standard"
              sx={{ "& .MuiInputBase-input": { color: "error.main" } }}
            />
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={submitting}>
          Cancel
        </Button>
        <Button
          onClick={handleSubmit}
          variant="contained"
          disabled={!valid || submitting}
        >
          {employee ? "Save" : "Create"}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
