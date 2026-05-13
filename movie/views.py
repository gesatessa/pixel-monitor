# movie/views.py

from django.db import IntegrityError
from rest_framework import viewsets, permissions, authentication, status

from core.models import Movie
from .serializers import MovieSerializer


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
