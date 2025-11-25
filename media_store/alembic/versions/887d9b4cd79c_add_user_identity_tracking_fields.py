"""Add user identity tracking fields

Revision ID: 887d9b4cd79c
Revises: d1c4fa6f5bb5
Create Date: 2025-11-25 16:40:07.855033

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '887d9b4cd79c'
down_revision: Union[str, None] = 'd1c4fa6f5bb5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Add added_by column
    op.add_column('entities', sa.Column('added_by', sa.String(), nullable=True))
    
    # Add updated_by column
    op.add_column('entities', sa.Column('updated_by', sa.String(), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    # Remove updated_by column
    op.drop_column('entities', 'updated_by')
    
    # Remove added_by column
    op.drop_column('entities', 'added_by')
