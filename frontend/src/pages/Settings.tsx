import {
  Box,
  Card,
  CardContent,
  Divider,
  List,
  ListItem,
  ListItemText,
  Typography,
} from "@mui/material";
import { useAuth } from "../hooks/useAuth";

export default function Settings() {
  const { user } = useAuth();

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Settings
      </Typography>
      <Card sx={{ maxWidth: 560, mt: 2 }} elevation={2}>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Application
          </Typography>
          <List dense>
            <ListItem disableGutters>
              <ListItemText primary="Version" secondary="1.0.0 (Phase 1)" />
            </ListItem>
            <Divider component="li" />
            <ListItem disableGutters>
              <ListItemText primary="Signed in as" secondary={user?.username ?? "—"} />
            </ListItem>
            <Divider component="li" />
            <ListItem disableGutters>
              <ListItemText
                primary="Access level"
                secondary={user?.role ?? "—"}
                secondaryTypographyProps={{ sx: { textTransform: "capitalize" } }}
              />
            </ListItem>
          </List>
          <Typography variant="body2" color="text.secondary" mt={2}>
            Additional preferences will be available in a future phase.
          </Typography>
        </CardContent>
      </Card>
    </Box>
  );
}
