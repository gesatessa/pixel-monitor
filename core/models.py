from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.db import models
from django.utils import timezone

from .managers import UserManager


class User(AbstractBaseUser, PermissionsMixin):
    email = models.EmailField(unique=True)
    is_staff = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    date_joined = models.DateTimeField(default=timezone.now)

    USERNAME_FIELD = "email"  # <—— use email to log in
    REQUIRED_FIELDS = []

    objects = UserManager()

    def __str__(self):
        return self.email

# movie ======================================= #

from django.conf import settings
from django.core.validators import MinValueValidator, MaxValueValidator

import os
import uuid


def movie_image_file_path(instance, filename):
    """Generate file path for new movie image."""

    name, ext = os.path.splitext(filename)

    unique_id = uuid.uuid4().hex[:10]

    filename = f"{name}_{unique_id}{ext}"

    return os.path.join(
        'uploads',
        'movies',
        filename,
    )


class Movie(models.Model):
    title = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    release_year = models.PositiveIntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    poster = models.ImageField(
        upload_to=movie_image_file_path,
        null=True,
        blank=True,
    )

    def __str__(self):
        return self.title


class Review(models.Model):
    movie = models.ForeignKey(Movie, on_delete=models.CASCADE, related_name='reviews')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    rating = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)]
    )
    comment = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['movie', 'user'],
                name='unique_review_per_user_per_movie'
            )
        ]

    def __str__(self):
        return f'{self.user.email} - {self.movie.title}'


class Like(models.Model):
    movie = models.ForeignKey(Movie, on_delete=models.CASCADE, related_name='likes')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['movie', 'user'],
                name='unique_like_per_user_per_movie'
            )
        ]

    def __str__(self):
        return f'{self.user.email} likes {self.movie.title}'
