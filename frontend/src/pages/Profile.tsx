import {
  Avatar,
  Box,
  Card,
  CardContent,
  Chip,
  Divider,
  Stack,
  Typography,
} from "@mui/material";
import { useAuth } from "../hooks/useAuth";

export default function Profile() {
  const { user } = useAuth();
  if (!user) return null;

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Profile
      </Typography>
      <Card sx={{ maxWidth: 480, mt: 2 }} elevation={2}>
        <CardContent>
          <Stack direction="row" spacing={2} alignItems="center" mb={2}>
            <Avatar sx={{ width: 64, height: 64, fontSize: 28 }}>
              {user.username.charAt(0).toUpperCase()}
            </Avatar>
            <Box>
              <Typography variant="h6">{user.username}</Typography>
              <Chip
                label={user.role}
                size="small"
                color="primary"
                sx={{ textTransform: "capitalize", mt: 0.5 }}
              />
            </Box>
          </Stack>
          <Divider sx={{ my: 2 }} />
          <Stack spacing={1}>
            <Row label="User ID" value={String(user.id)} />
            <Row label="Username" value={user.username} />
            <Row label="Role" value={user.role} />
          </Stack>
        </CardContent>
      </Card>
    </Box>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <Stack direction="row" justifyContent="space-between">
      <Typography color="text.secondary">{label}</Typography>
      <Typography sx={{ textTransform: "capitalize" }}>{value}</Typography>
    </Stack>
  );
}
