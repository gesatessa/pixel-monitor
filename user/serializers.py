from django.contrib.auth import get_user_model

from rest_framework import serializers


class UserSerializer(serializers.ModelSerializer):
    
    class Meta:
        model = get_user_model()
        # required fields when making a request to create a user
        fields = ['email', 'password']
        # extra validation checks
        # wirte_only: true: do NOT return the value (security)
        # if `min_length` is not satisfied, it sends 400 bad request
        extra_kwargs = {
            'password': {'write_only': True, 'min_length': 8}
        }

    def create(self, validated_data):
        # if the validation works, call `.create_user()` method from the UserManager
        return get_user_model().objects.create_user(**validated_data)
