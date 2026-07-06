import { useState } from "react";
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  IconButton,
  InputAdornment,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from "@mui/material";
import AddIcon from "@mui/icons-material/Add";
import EditIcon from "@mui/icons-material/Edit";
import DeleteIcon from "@mui/icons-material/Delete";
import SearchIcon from "@mui/icons-material/Search";
import { AxiosError } from "axios";
import EmployeeDialog from "../components/EmployeeDialog";
import ConfirmDialog from "../components/ConfirmDialog";
import { useDepartments } from "../hooks/useDepartments";
import {
  useCreateEmployee,
  useDeleteEmployee,
  useEmployees,
  useUpdateEmployee,
} from "../hooks/useEmployees";
import { useAuth } from "../hooks/useAuth";
import type { Employee, EmployeeInput } from "../types";

export default function Employees() {
  const { hasRole } = useAuth();
  const canManage = hasRole("admin", "manager");
  const canDelete = hasRole("admin");

  const [search, setSearch] = useState("");
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Employee | null>(null);
  const [deleting, setDeleting] = useState<Employee | null>(null);
  const [formError, setFormError] = useState<string | null>(null);

  const { data: employees, isLoading } = useEmployees(search);
  const { data: departments = [] } = useDepartments();
  const createMut = useCreateEmployee();
  const updateMut = useUpdateEmployee();
  const deleteMut = useDeleteEmployee();

  const openAdd = () => {
    setEditing(null);
    setFormError(null);
    setDialogOpen(true);
  };

  const openEdit = (employee: Employee) => {
    setEditing(employee);
    setFormError(null);
    setDialogOpen(true);
  };

  const handleSubmit = async (input: EmployeeInput) => {
    setFormError(null);
    try {
      if (editing) {
        await updateMut.mutateAsync({ id: editing.id, input });
      } else {
        await createMut.mutateAsync(input);
      }
      setDialogOpen(false);
    } catch (err) {
      const axiosErr = err as AxiosError<{ detail?: string }>;
      setFormError(axiosErr.response?.data?.detail ?? "Something went wrong.");
    }
  };

  const handleDelete = async () => {
    if (!deleting) return;
    await deleteMut.mutateAsync(deleting.id);
    setDeleting(null);
  };

  return (
    <Box>
      <Stack
        direction={{ xs: "column", sm: "row" }}
        justifyContent="space-between"
        alignItems={{ sm: "center" }}
        spacing={2}
        mb={3}
      >
        <Typography variant="h4">Employees</Typography>
        {canManage && (
          <Button variant="contained" startIcon={<AddIcon />} onClick={openAdd}>
            Add Employee
          </Button>
        )}
      </Stack>

      <TextField
        placeholder="Search by name, email or designation…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        fullWidth
        sx={{ mb: 2, maxWidth: 420 }}
        InputProps={{
          startAdornment: (
            <InputAdornment position="start">
              <SearchIcon />
            </InputAdornment>
          ),
        }}
      />

      {isLoading ? (
        <Box display="flex" justifyContent="center" mt={4}>
          <CircularProgress />
        </Box>
      ) : !employees || employees.length === 0 ? (
        <Alert severity="info">No employees found.</Alert>
      ) : (
        <TableContainer component={Paper}>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Name</TableCell>
                <TableCell>Email</TableCell>
                <TableCell>Designation</TableCell>
                <TableCell>Department</TableCell>
                <TableCell>Status</TableCell>
                {canManage && <TableCell align="right">Actions</TableCell>}
              </TableRow>
            </TableHead>
            <TableBody>
              {employees.map((emp) => (
                <TableRow key={emp.id} hover>
                  <TableCell>
                    {emp.first_name} {emp.last_name}
                  </TableCell>
                  <TableCell>{emp.email}</TableCell>
                  <TableCell>{emp.designation ?? "—"}</TableCell>
                  <TableCell>{emp.department?.name ?? "—"}</TableCell>
                  <TableCell>
                    <Chip
                      label={emp.is_active ? "Active" : "Inactive"}
                      color={emp.is_active ? "success" : "default"}
                      size="small"
                    />
                  </TableCell>
                  {canManage && (
                    <TableCell align="right">
                      <Tooltip title="Edit">
                        <IconButton size="small" onClick={() => openEdit(emp)}>
                          <EditIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                      {canDelete && (
                        <Tooltip title="Delete">
                          <IconButton
                            size="small"
                            color="error"
                            onClick={() => setDeleting(emp)}
                          >
                            <DeleteIcon fontSize="small" />
                          </IconButton>
                        </Tooltip>
                      )}
                    </TableCell>
                  )}
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <EmployeeDialog
        open={dialogOpen}
        employee={editing}
        departments={departments}
        onClose={() => setDialogOpen(false)}
        onSubmit={handleSubmit}
        submitting={createMut.isPending || updateMut.isPending}
        error={formError}
      />

      <ConfirmDialog
        open={Boolean(deleting)}
        title="Delete Employee"
        message={`Delete ${deleting?.first_name} ${deleting?.last_name}? This cannot be undone.`}
        onCancel={() => setDeleting(null)}
        onConfirm={handleDelete}
        loading={deleteMut.isPending}
      />
    </Box>
  );
}
