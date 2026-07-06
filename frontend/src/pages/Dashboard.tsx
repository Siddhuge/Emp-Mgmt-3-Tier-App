import { Alert, Box, CircularProgress, Typography } from "@mui/material";
import PeopleIcon from "@mui/icons-material/People";
import ApartmentIcon from "@mui/icons-material/Apartment";
import WorkIcon from "@mui/icons-material/Work";
import CheckCircleIcon from "@mui/icons-material/CheckCircle";
import StatCard from "../components/StatCard";
import { useDashboard } from "../hooks/useDashboard";

export default function Dashboard() {
  const { data, isLoading, isError } = useDashboard();

  if (isLoading) {
    return (
      <Box display="flex" justifyContent="center" mt={4}>
        <CircularProgress />
      </Box>
    );
  }

  if (isError || !data) {
    return <Alert severity="error">Failed to load dashboard.</Alert>;
  }

  const cards = [
    {
      label: "Total Employees",
      value: data.total_employees,
      icon: <PeopleIcon />,
      color: "#1976d2",
    },
    {
      label: "Departments",
      value: data.departments,
      icon: <ApartmentIcon />,
      color: "#9c27b0",
    },
    {
      label: "Projects",
      value: data.projects,
      icon: <WorkIcon />,
      color: "#ed6c02",
    },
    {
      label: "Active Employees",
      value: data.active_employees,
      icon: <CheckCircleIcon />,
      color: "#2e7d32",
    },
  ];

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Dashboard
      </Typography>
      <Box
        sx={{
          display: "grid",
          gap: 3,
          mt: 2,
          gridTemplateColumns: {
            xs: "1fr",
            sm: "1fr 1fr",
            lg: "repeat(4, 1fr)",
          },
        }}
      >
        {cards.map((c) => (
          <StatCard key={c.label} {...c} />
        ))}
      </Box>
    </Box>
  );
}
