from django.db.models import Avg
from rest_framework import serializers

from core.models import Movie


class MovieSerializer(serializers.ModelSerializer):
    # average_rating = serializers.SerializerMethodField()

    class Meta:
        model = Movie
        fields = [
            'id',
            'title',
            'description',
            'release_year',
        ]

