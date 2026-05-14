import { useEffect, useState } from "react";

import {
  Link,
  useNavigate,
  useParams,
} from "react-router-dom";

import api from "../api/axios";

type Review = {
  id: number;
  user: string;
  rating: number;
  comment: string;
};

type Movie = {
  id: number;
  title: string;
  description: string;
  release_year: number;
  poster: string | null;
  average_rating: number | null;
  likes_count: number;
  reviews: Review[];
};

type User = {
  email: string;
};

export default function MovieDetailPage() {
  const { id } = useParams();

  const navigate = useNavigate();

  const [movie, setMovie] =
    useState<Movie | null>(null);

  const [user, setUser] =
    useState<User | null>(null);

  const [loading, setLoading] =
    useState(true);

  const [comment, setComment] =
    useState("");

  const [rating, setRating] =
    useState(5);

  useEffect(() => {
    async function fetchData() {
      try {
        const movieResponse =
          await api.get(
            `/movies/${id}/`
          );

        setMovie(movieResponse.data);

        try {
          const userResponse =
            await api.get("/user/me/");

          setUser(userResponse.data);
        } catch {
          setUser(null);
        }
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    }

    fetchData();
  }, [id]);

  async function handleReviewSubmit(
    e: React.FormEvent
  ) {
    e.preventDefault();

    if (!user) {
      navigate("/");

      return;
    }

    try {
      await api.post(
        `/movies/${id}/review/`,
        {
          rating,
          comment,
        }
      );

      const response =
        await api.get(
          `/movies/${id}/`
        );

      setMovie(response.data);

      setComment("");
      setRating(5);
    } catch (err) {
      console.error(err);
    }
  }

  async function handleLike() {
    if (!user) {
      navigate("/");

      return;
    }

    try {
      const response = await api.post(
        `/movies/${id}/like/`
      );

      const liked =
        response.data.liked;

      setMovie((prev) => {
        if (!prev) {
          return prev;
        }

        return {
          ...prev,
          likes_count: liked
            ? prev.likes_count + 1
            : prev.likes_count - 1,
        };
      });
    } catch (err) {
      console.error(err);
    }
  }

  if (loading || !movie) {
    return (
      <div className="min-h-screen bg-zinc-900 text-white p-8">
        Loading...
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-zinc-900 text-white">
      <div className="p-6">
        <Link
          to="/movies"
          className="inline-flex items-center gap-2 text-zinc-400 hover:text-white"
        >
          ← Back to movies
        </Link>
      </div>

      {movie.poster && (
        <img
          src={movie.poster}
          alt={movie.title}
          className="w-full h-[500px] object-cover"
        />
      )}

      <div className="max-w-5xl mx-auto p-8">
        <div className="flex justify-between items-start mb-8">
          <div>
            <h1 className="text-5xl font-bold mb-2">
              {movie.title}
            </h1>

            <p className="text-zinc-400 text-xl mb-4">
              {movie.release_year}
            </p>

            <div className="flex items-center gap-6 text-lg">
              <span>
                ⭐{" "}
                {movie.average_rating ??
                  "N/A"}
              </span>

              <button
                onClick={handleLike}
                className="hover:scale-110 transition"
              >
                ❤️ {movie.likes_count}
              </button>
            </div>
          </div>
        </div>

        <p className="text-lg text-zinc-300 mb-10">
          {movie.description}
        </p>

        <div className="mb-12">
          <h2 className="text-3xl font-bold mb-6">
            Reviews
          </h2>

          {movie.reviews.length === 0 ? (
            <p className="text-zinc-500">
              No reviews yet.
            </p>
          ) : (
            <div className="space-y-4">
              {movie.reviews.map(
                (review) => (
                  <div
                    key={review.id}
                    className="bg-zinc-800 p-5 rounded-xl"
                  >
                    <div className="flex justify-between mb-3">
                      <span className="font-semibold">
                        {review.user}
                      </span>

                      <span>
                        ⭐ {review.rating}
                      </span>
                    </div>

                    <p className="text-zinc-300">
                      {review.comment}
                    </p>
                  </div>
                )
              )}
            </div>
          )}
        </div>

        <div>
          <h2 className="text-3xl font-bold mb-6">
            Leave a review
          </h2>

          {!user ? (
            <button
              onClick={() =>
                navigate("/")
              }
              className="bg-blue-600 px-6 py-3 rounded-xl hover:bg-blue-500"
            >
              Login to review
            </button>
          ) : (
            <form
              onSubmit={
                handleReviewSubmit
              }
              className="space-y-4"
            >
              <select
                value={rating}
                onChange={(e) =>
                  setRating(
                    Number(
                      e.target.value
                    )
                  )
                }
                className="bg-zinc-800 p-3 rounded"
              >
                <option value={1}>
                  1
                </option>
                <option value={2}>
                  2
                </option>
                <option value={3}>
                  3
                </option>
                <option value={4}>
                  4
                </option>
                <option value={5}>
                  5
                </option>
              </select>

              <textarea
                value={comment}
                onChange={(e) =>
                  setComment(
                    e.target.value
                  )
                }
                placeholder="Write your review..."
                className="w-full bg-zinc-800 p-4 rounded-xl min-h-[150px]"
              />

              <button
                type="submit"
                className="bg-blue-600 px-6 py-3 rounded-xl hover:bg-blue-500"
              >
                Submit Review
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
