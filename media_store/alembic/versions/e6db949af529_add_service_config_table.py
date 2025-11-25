"""Add service config table

Revision ID: e6db949af529
Revises: 887d9b4cd79c
Create Date: 2025-11-25 17:15:09.903737

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e6db949af529'
down_revision: Union[str, None] = '887d9b4cd79c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Create service_config table
    op.create_table(
        'service_config',
        sa.Column('key', sa.String(), nullable=False),
        sa.Column('value', sa.String(), nullable=False),
        sa.Column('updated_at', sa.BigInteger(), nullable=False),
        sa.Column('updated_by', sa.String(), nullable=True),
        sa.PrimaryKeyConstraint('key')
    )
    
    # Insert default configuration
    from datetime import datetime
    op.execute(
        f"INSERT INTO service_config (key, value, updated_at, updated_by) "
        f"VALUES ('read_auth_enabled', 'false', {int(datetime.utcnow().timestamp() * 1000)}, NULL)"
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('service_config')
