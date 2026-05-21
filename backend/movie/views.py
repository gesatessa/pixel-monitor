from django.db import IntegrityError
from rest_framework import viewsets, permissions, authentication, status
from rest_framework.decorators import action
from rest_framework.response import Response

from core.models import Movie, Review, Like
from .serializers import EmptySerializer, MovieSerializer, CreateReviewSerializer

import logging

logger = logging.getLogger(__name__)


class IsAdminOrReadOnly(permissions.BasePermission):
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True

        return request.user and request.user.is_staff


class MovieViewSet(viewsets.ModelViewSet):
    queryset = Movie.objects.all().order_by('-created_at')
    serializer_class = MovieSerializer
    authentication_classes = [authentication.TokenAuthentication]
    permission_classes = [IsAdminOrReadOnly]

    # Override get_serializer_class to return different serializers for different actions
    # in the swagger docs, it will show the correct request body for each action (e.g., review, like)
    def get_serializer_class(self):
        if self.action == 'review':
            return CreateReviewSerializer
        
        if self.action == 'like':
            return EmptySerializer

        return MovieSerializer

    # 📢 Override perform_create to log movie creation with user info
    # otherwise, this works behind the scenes and we have no visibility into which user created which movie.
    def perform_create(self, serializer):
        movie = serializer.save()

        logger.info(
            "Movie created id=%s title='%s' by user_id=%s (email=%s)",
            movie.id,
            movie.title,
            self.request.user.id,
            self.request.user.email,
        )

    @action(
        detail=True,
        methods=['post'],
        permission_classes=[permissions.IsAuthenticated],
        authentication_classes=[authentication.TokenAuthentication],
    )
    def like(self, request, pk=None):
        movie = self.get_object()

        like, created = Like.objects.get_or_create(
            movie=movie,
            user=request.user,
        )

        if not created:
            like.delete()
            logger.info(
                "User %s unliked movie_id=%s",
                request.user.id,
                movie.id,
            )
            return Response({'liked': False}, status=status.HTTP_200_OK)

        logger.info(
            "User %s liked movie_id=%s",
            request.user.id,
            movie.id,
        )
        return Response({'liked': True}, status=status.HTTP_201_CREATED)

    @action(
        detail=True,
        methods=['post'],
        permission_classes=[permissions.IsAuthenticated],
        authentication_classes=[authentication.TokenAuthentication],
    )
    def review(self, request, pk=None):
        movie = self.get_object()
        # serializer = CreateReviewSerializer(data=request.data)
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            review = Review.objects.create(
                movie=movie,
                user=request.user,
                **serializer.validated_data,
            )
        except IntegrityError:
            logger.warning(
                "Duplicate review attempt user_id=%s movie_id=%s",
                request.user.id,
                movie.id,
            )
            return Response(
                {'detail': 'You already reviewed this movie.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        logger.info(
            "User %s reviewed movie_id=%s",
            request.user.id,
            movie.id,
        )
        return Response(
            {
                'id': review.id,
                'rating': review.rating,
                'comment': review.comment,
            },
            status=status.HTTP_201_CREATED,
        )
