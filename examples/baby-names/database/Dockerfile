FROM liquibase/liquibase:4.25

# Copy changelogs and data
COPY changelog /liquibase/changelog
COPY data /data

# Set working directory
WORKDIR /liquibase

# Default command runs update
CMD ["--changelog-file=changelog/db.changelog-master.yaml", "update"]
