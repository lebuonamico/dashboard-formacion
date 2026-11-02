String normalizeTeamName(String team) =>
    team.trim().isEmpty ? 'Sin equipo asignado' : team.trim();
