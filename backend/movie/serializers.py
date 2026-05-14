from django.db.models import Avg
from rest_framework import serializers

from core.models import Movie, Review, Like


class EmptySerializer(serializers.Serializer):
    pass


class ReviewSerializer(serializers.ModelSerializer):
    user = serializers.EmailField(source='user.email', read_only=True)

    class Meta:
        model = Review
        fields = ['id', 'user', 'rating', 'comment', 'created_at']
        read_only_fields = ['id', 'user', 'created_at']


class MovieSerializer(serializers.ModelSerializer):
    reviews = ReviewSerializer(many=True, read_only=True)
    average_rating = serializers.SerializerMethodField()
    likes_count = serializers.SerializerMethodField()
    # poster = serializers.SerializerMethodField()

    class Meta:
        model = Movie
        fields = [
            'id',
            'title',
            'description',
            'release_year',
            'average_rating',
            'likes_count',
            'reviews',
            'poster',
        ]

    def get_average_rating(self, obj):
        result = obj.reviews.aggregate(avg=Avg('rating'))
        return result['avg']

    def get_likes_count(self, obj):
        return obj.likes.count()
    
    # def get_poster(self, obj):
    #     request = self.context.get('request')

    #     if obj.poster and request:
    #         return request.build_absolute_uri(
    #             obj.poster.url
    #         )

    #     return None


class CreateReviewSerializer(serializers.ModelSerializer):
    class Meta:
        model = Review
        fields = ['rating', 'comment']
