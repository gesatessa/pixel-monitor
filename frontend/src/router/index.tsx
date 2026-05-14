import {
  createBrowserRouter,
} from "react-router-dom";

import LoginPage from "../pages/LoginPage";
import MoviesPage from "../pages/MoviesPage";
import MovieDetailPage from "../pages/MovieDetailPage";

const router = createBrowserRouter([
  {
    path: "/",
    element: <LoginPage />,
  },
  {
    path: "/movies",
    element: <MoviesPage />,
  },
  {
    path: "/movies/:id",
    element: <MovieDetailPage />,
  },
]);

export default router;
