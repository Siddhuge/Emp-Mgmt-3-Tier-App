import { useState } from "react";
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from "@mui/material";
import AddIcon from "@mui/icons-material/Add";
import { AxiosError } from "axios";
import { useCreateDepartment, useDepartments } from "../hooks/useDepartments";
import { useAuth } from "../hooks/useAuth";

export default function Departments() {
  const { hasRole } = useAuth();
  const canManage = hasRole("admin", "manager");

  const { data: departments, isLoading } = useDepartments();
  const createMut = useCreateDepartment();

  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [manager, setManager] = useState("");
  const [error, setError] = useState<string | null>(null);

  const close = () => {
    setOpen(false);
    setName("");
    setManager("");
    setError(null);
  };

  const submit = async () => {
    setError(null);
    try {
      await createMut.mutateAsync({ name, manager: manager || null });
      close();
    } catch (err) {
      const axiosErr = err as AxiosError<{ detail?: string }>;
      setError(axiosErr.response?.data?.detail ?? "Something went wrong.");
    }
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
        <Typography variant="h4">Departments</Typography>
        {canManage && (
          <Button variant="contained" startIcon={<AddIcon />} onClick={() => setOpen(true)}>
            Add Department
          </Button>
        )}
      </Stack>

      {isLoading ? (
        <Box display="flex" justifyContent="center" mt={4}>
          <CircularProgress />
        </Box>
      ) : !departments || departments.length === 0 ? (
        <Alert severity="info">No departments yet.</Alert>
      ) : (
        <TableContainer component={Paper}>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>ID</TableCell>
                <TableCell>Name</TableCell>
                <TableCell>Manager</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {departments.map((d) => (
                <TableRow key={d.id} hover>
                  <TableCell>{d.id}</TableCell>
                  <TableCell>{d.name}</TableCell>
                  <TableCell>{d.manager ?? "—"}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <Dialog open={open} onClose={close} fullWidth maxWidth="sm">
        <DialogTitle>Add Department</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            {error && <Alert severity="error">{error}</Alert>}
            <TextField
              label="Name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              fullWidth
              required
              autoFocus
            />
            <TextField
              label="Manager"
              value={manager}
              onChange={(e) => setManager(e.target.value)}
              fullWidth
            />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={close} disabled={createMut.isPending}>
            Cancel
          </Button>
          <Button
            onClick={submit}
            variant="contained"
            disabled={!name || createMut.isPending}
          >
            Create
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
