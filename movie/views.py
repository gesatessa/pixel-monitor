from django.db import IntegrityError
from rest_framework import viewsets, permissions, authentication, status
from rest_framework.decorators import action
from rest_framework.response import Response

from core.models import Movie, Review, Like
from .serializers import MovieSerializer, CreateReviewSerializer


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

    def get_serializer_class(self):
        if self.action == 'review':
            return CreateReviewSerializer

        return MovieSerializer

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
            return Response({'liked': False}, status=status.HTTP_200_OK)

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
            return Response(
                {'detail': 'You already reviewed this movie.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            {
                'id': review.id,
                'rating': review.rating,
                'comment': review.comment,
            },
            status=status.HTTP_201_CREATED,
        )
