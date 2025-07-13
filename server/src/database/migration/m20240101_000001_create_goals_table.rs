use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Goals::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Goals::Id)
                            .uuid()
                            .not_null()
                            .primary_key()
                            .extra("DEFAULT gen_random_uuid()"),
                    )
                    .col(ColumnDef::new(Goals::Name).string().not_null())
                    .col(ColumnDef::new(Goals::Description).text())
                    .col(
                        ColumnDef::new(Goals::Status)
                            .string()
                            .not_null()
                            .default("NotStarted"),
                    )
                    .col(ColumnDef::new(Goals::StartDate).text()) // Changed to text for ISO strings
                    .col(ColumnDef::new(Goals::TargetDate).text()) // Changed to text for ISO strings
                    .col(
                        ColumnDef::new(Goals::StudyIds)
                            .array(ColumnType::Text)
                            .not_null()
                            .default("{}"),
                    ) // Not nullable, default to empty array
                    .col(ColumnDef::new(Goals::TempoTarget).integer().unsigned())
                    .col(
                        ColumnDef::new(Goals::CreatedAt)
                            .timestamp_with_time_zone()
                            .default(Expr::current_timestamp()),
                    )
                    .col(
                        ColumnDef::new(Goals::UpdatedAt)
                            .timestamp_with_time_zone()
                            .default(Expr::current_timestamp()),
                    )
                    .to_owned(),
            )
            .await?;

        // Create indexes
        manager
            .create_index(
                Index::create()
                    .name("idx_goals_status")
                    .table(Goals::Table)
                    .col(Goals::Status)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_goals_target_date")
                    .table(Goals::Table)
                    .col(Goals::TargetDate)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_goals_created_at")
                    .table(Goals::Table)
                    .col(Goals::CreatedAt)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(Goals::Table).to_owned())
            .await
    }
}

#[derive(DeriveIden)]
enum Goals {
    Table,
    Id,
    Name,
    Description,
    Status,
    StartDate,
    TargetDate,
    StudyIds,
    TempoTarget,
    CreatedAt,
    UpdatedAt,
}
